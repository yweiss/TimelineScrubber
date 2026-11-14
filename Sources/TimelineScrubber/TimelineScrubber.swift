import SwiftUI

#if os(macOS)
  import AppKit
#endif

// Extracted from Memolio’s date rail. No app-specific storage, theme or haptics dependencies.
public struct TimelineScrubberStop: Identifiable, Hashable, Sendable {
  public let id: String
  public let sectionID: String
  public let date: Date
  public let label: String
  public init(id: String, sectionID: String, date: Date, label: String) {
    self.id = id
    self.sectionID = sectionID
    self.date = date
    self.label = label
  }
}

@MainActor
public struct TimelineScrubber: View {
  let thresholds: [TimelineScrubberStop]
  let tint: Color
  @Binding var isActive: Bool
  @Binding var isHovering: Bool
  @Binding var targetID: String?
  @Binding var expansionProgress: CGFloat
  let onScrubStart: () -> Void
  let onSelect: (String, Bool) -> Void
  let onScrubEnd: () -> Void

  private let selectionFeedback: () -> Void

  public init(
    thresholds: [TimelineScrubberStop], tint: Color = .accentColor,
    isActive: Binding<Bool>, isHovering: Binding<Bool>, targetID: Binding<String?>,
    expansionProgress: Binding<CGFloat>, onScrubStart: @escaping () -> Void = {},
    onSelect: @escaping (String, Bool) -> Void, onScrubEnd: @escaping () -> Void = {},
    selectionFeedback: @escaping () -> Void = { TimelineScrubberFeedback.selection() }
  ) {
    self.thresholds = thresholds
    self.tint = tint
    _isActive = isActive
    _isHovering = isHovering
    _targetID = targetID
    _expansionProgress = expansionProgress
    self.onScrubStart = onScrubStart
    self.onSelect = onSelect
    self.onScrubEnd = onScrubEnd
    self.selectionFeedback = selectionFeedback
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isExpanded = false
  @State private var isTouching = false
  @State private var scrubPositionY: CGFloat?
  @State private var activeThresholdIndex: Int?
  @State private var touchStartY: CGFloat?
  @State private var touchStartProgress: CGFloat?
  #if os(macOS)
    @State private var isHovered = false
    @State private var hoverPositionY: CGFloat?
  #endif

  private let collapsedWidth: CGFloat = 12
  private let expandedWidth: CGFloat = 38.4
  private let edgeActivationWidth: CGFloat = 20
  private let collapsedCoverageRatio: CGFloat = 0.75

  private var activeLabel: String? {
    if let activeThresholdIndex, thresholds.indices.contains(activeThresholdIndex) {
      return thresholds[activeThresholdIndex].label
    }

    guard let targetID else { return thresholds.first?.label }
    return thresholds.first(where: { $0.sectionID == targetID })?.label ?? thresholds.first?.label
  }

  private var tickWidth: CGFloat {
    isExpanded ? 12 : 9.6
  }

  private var tickHeight: CGFloat {
    isExpanded ? 4 : 3
  }

  public var body: some View {
    GeometryReader { proxy in
      let scrubberHeight = min(proxy.size.height * 0.9, 900)
      let scrubberWidth = collapsedWidth + ((expandedWidth - collapsedWidth) * expansionProgress)
      let scrubberTop = (proxy.size.height - scrubberHeight) / 2

      ZStack(alignment: .trailing) {
        if isTouching, let activeLabel {
          Text(activeLabel)
            .font(.title3.weight(.bold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, 22)
            .frame(height: 50)
            .modifier(TimelineScrubberLabelGlassModifier(tint: tint))
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .transition(.scale(scale: 0.82).combined(with: .opacity))
        }

        Color.clear
          .frame(width: edgeActivationWidth, height: proxy.size.height)
          .contentShape(Rectangle())
          .overlay(alignment: .trailing) {
            scrubberStack(height: scrubberHeight)
              .frame(width: scrubberWidth, height: scrubberHeight, alignment: .center)
          }
          .highPriorityGesture(scrubGesture(height: scrubberHeight, verticalOffset: scrubberTop))
          #if os(macOS)
            .onContinuousHover(coordinateSpace: .local) { phase in
              switch phase {
              case .active(let location):
                isHovered = true
                isHovering = true
                hoverPositionY = min(max(location.y - scrubberTop, 0), scrubberHeight)
                updateCursor()
              case .ended:
                isHovered = false
                isHovering = false
                hoverPositionY = nil
                updateCursor()
              }
            }
          #endif
          .position(
            x: proxy.size.width - (edgeActivationWidth / 2),
            y: proxy.size.height / 2
          )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .transaction { if reduceMotion { $0.animation = nil } }
    .opacity(isActive ? 1 : 0.92)
    .animation(.easeOut(duration: 0.16), value: isActive)
    .animation(.spring(response: 0.34, dampingFraction: 0.72), value: isTouching)
    #if os(macOS)
      .animation(.easeOut(duration: 0.12), value: isHovered)
      .onChange(of: isTouching) { _, _ in
        updateCursor()
      }
      .onDisappear {
        isHovering = false
        hoverPositionY = nil
        NSCursor.arrow.set()
      }
    #endif
  }

  private func scrubGesture(height: CGFloat, verticalOffset: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .local)
      .onChanged { value in
        let scrubberLocation = CGPoint(x: value.location.x, y: value.location.y - verticalOffset)
        if !isTouching {
          beginScrubbing(at: scrubberLocation, height: height)
        } else {
          updateSelection(at: scrubberLocation, height: height)
        }
      }
      .onEnded { _ in
        endScrubbing()
      }
  }

  private func scrubberStack(height: CGFloat) -> some View {
    let visibleIndices = visibleIndices(for: height)
    let spacing = tickSpacing(for: height, count: visibleIndices.count)
    let totalTickHeight = CGFloat(visibleIndices.count) * tickHeight
    let totalSpacingHeight = CGFloat(max(visibleIndices.count - 1, 0)) * spacing
    let verticalInset = max((height - totalTickHeight - totalSpacingHeight) / 2, 0)
    let focusPosition = scrubFocusPosition(visibleIndices: visibleIndices, height: height)

    return VStack(spacing: spacing) {
      ForEach(Array(visibleIndices.enumerated()), id: \.element) { offset, index in
        let threshold = thresholds[index]
        Button {
          targetID = threshold.sectionID
          activeThresholdIndex = index
          selectionFeedback()
          onSelect(threshold.sectionID, true)
          collapseScrubber()
        } label: {
          scrubberTick(visibleOffset: offset, focusPosition: focusPosition)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Jump to \(threshold.label)"))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .padding(.top, verticalInset)
    .animation(.spring(response: 0.26, dampingFraction: 0.84), value: isExpanded)
    .animation(.spring(response: 0.22, dampingFraction: 0.86), value: activeThresholdIndex)
    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: scrubPositionY)
  }

  private func scrubberTick(visibleOffset: Int, focusPosition: CGFloat?) -> some View {
    let distance = abs(CGFloat(visibleOffset) - (focusPosition ?? CGFloat(visibleOffset)))
    let bell = max(0, 1 - min(distance / 3.6, 1))
    let width = tickWidth + (isExpanded ? bell * 24 : 0)
    #if os(macOS)
      let hoverOpacity: CGFloat? = isHovered && !isTouching ? (0.32 + (bell * 0.48)) : nil
    #else
      let hoverOpacity: CGFloat? = nil
    #endif
    let opacity = hoverOpacity ?? min(isExpanded ? 0.32 + (bell * 0.68) : 0.74, 1)
    let verticalScale = isExpanded ? (1 + (bell * 0.1)) : 1

    return RoundedRectangle(cornerRadius: tickHeight / 2, style: .continuous)
      .fill(tint.opacity(opacity))
      .frame(width: width, height: tickHeight)
      .scaleEffect(x: 1, y: verticalScale, anchor: .trailing)
  }

  private func visibleIndices(for height: CGFloat) -> [Int] {
    guard !thresholds.isEmpty else { return [] }
    // Budget for the expanded tick's slight scale-up as well as a visible gap.
    let minimumGap: CGFloat = isExpanded ? 5 : 9
    let renderedTickHeight = tickHeight * (isExpanded ? 1.1 : 1)
    let coveredHeight = max(0, height * (isExpanded ? 1 : collapsedCoverageRatio))
    let capacity = max(1, Int((coveredHeight + minimumGap) / (renderedTickHeight + minimumGap)))
    let count = min(thresholds.count, capacity)
    guard count > 1 else {
      return [min(max(activeThresholdIndex ?? 0, 0), thresholds.count - 1)]
    }
    guard count < thresholds.count else { return Array(thresholds.indices) }

    // Sample evenly, preserving both ends. Selection still uses every threshold.
    var indices = (0..<count).map {
      Int((Double($0) * Double(thresholds.count - 1) / Double(count - 1)).rounded())
    }
    if let activeThresholdIndex,
      thresholds.indices.contains(activeThresholdIndex),
      !indices.contains(activeThresholdIndex),
      count > 2
    {
      let replacement =
        (1..<(count - 1)).min {
          abs(indices[$0] - activeThresholdIndex) < abs(indices[$1] - activeThresholdIndex)
        } ?? 1
      indices[replacement] = activeThresholdIndex
    }
    return indices.sorted()
  }

  private func tickSpacing(for height: CGFloat, count: Int) -> CGFloat {
    guard count > 1 else { return 0 }
    let availableSpacing = max(height - (CGFloat(count) * tickHeight), 0)
    return min(8, availableSpacing / CGFloat(count - 1))
  }

  private func scrubFocusPosition(visibleIndices: [Int], height: CGFloat) -> CGFloat? {
    guard !visibleIndices.isEmpty else { return nil }

    #if os(macOS)
      if isHovered, let hoverPositionY {
        let step = height / CGFloat(visibleIndices.count)
        let fractionalIndex = (hoverPositionY / max(step, 1)) - 0.5
        return min(max(fractionalIndex, 0), CGFloat(visibleIndices.count - 1))
      }
    #endif

    guard let activeThresholdIndex else { return nil }
    if let visibleOffset = visibleIndices.firstIndex(of: activeThresholdIndex) {
      return CGFloat(visibleOffset)
    }

    let nearestVisibleOffset =
      visibleIndices.enumerated().min { lhs, rhs in
        abs(lhs.element - activeThresholdIndex) < abs(rhs.element - activeThresholdIndex)
      }?.offset ?? 0
    return CGFloat(nearestVisibleOffset)
  }

  private func beginScrubbing(at location: CGPoint, height: CGFloat) {
    onScrubStart()
    isActive = true
    // Select against the COLLAPSED geometry before expanding it. Anchoring
    // subsequent motion here prevents an activation jump under the finger.
    let count = visibleIndices(for: height).count
    let span = CGFloat(max(count - 1, 0)) * (tickHeight + tickSpacing(for: height, count: count))
    touchStartY = min(max(location.y, 0), height)
    touchStartProgress =
      count > 1 ? min(max((location.y - (height - span) / 2) / max(span, 1), 0), 1) : 0
    updateSelection(at: location, height: height)
    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
      isTouching = true
      isExpanded = true
      expansionProgress = 1
    }
  }

  private func updateSelection(at location: CGPoint, height: CGFloat) {
    guard !thresholds.isEmpty else { return }

    let clampedY = min(max(location.y, 0), height)
    scrubPositionY = clampedY

    let start = touchStartY ?? clampedY
    let initial = touchStartProgress ?? 0
    let progress: CGFloat
    if clampedY >= start {
      progress = initial + (1 - initial) * (clampedY - start) / max(height - start, 1)
    } else {
      progress = initial * clampedY / max(start, 1)
    }
    let index =
      TimelineScrubberIndex.index(progress: Double(progress), count: thresholds.count) ?? 0
    guard activeThresholdIndex != index else { return }

    activeThresholdIndex = index
    let threshold = thresholds[index]
    targetID = threshold.sectionID
    selectionFeedback()
    onSelect(threshold.sectionID, false)
  }

  private func collapseScrubber(animated: Bool = true) {
    if animated {
      withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
        isTouching = false
        isExpanded = false
        isActive = false
        expansionProgress = 0
      }
    } else {
      isTouching = false
      isExpanded = false
      isActive = false
      expansionProgress = 0
    }
    scrubPositionY = nil
    touchStartY = nil
    touchStartProgress = nil
  }

  private func endScrubbing() {
    collapseScrubber(animated: false)
    onScrubEnd()
  }

  #if os(macOS)
    private func updateCursor() {
      if isTouching {
        NSCursor.closedHand.set()
      } else if isHovered {
        NSCursor.openHand.set()
      } else {
        NSCursor.arrow.set()
      }
    }
  #endif
}

private struct TimelineScrubberLabelGlassModifier: ViewModifier {
  let tint: Color

  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  @ViewBuilder
  func body(content: Content) -> some View {
    if reduceTransparency {
      content
        .background(.background, in: Capsule())
        .overlay {
          Capsule().fill(tint.opacity(0.25))
        }
    } else if #available(iOS 26.0, macOS 26.0, *) {
      content.glassEffect(.regular.tint(tint.opacity(0.25)), in: Capsule())
    } else {
      content
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
          Capsule().fill(tint.opacity(0.25))
        }
    }
  }
}
