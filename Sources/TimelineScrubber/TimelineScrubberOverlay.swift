import SwiftUI

extension View {
  /// Attach to the scrolling viewport inside a ScrollViewReader. The overlay
  /// owns its interaction state; the host keeps ownership of scroll targets.
  @MainActor public func timelineScrubber(
    stops: [TimelineScrubberStop], tint: Color = .accentColor,
    currentID: Binding<String?> = .constant(nil),
    selectionFeedback: @escaping () -> Void = { TimelineScrubberFeedback.selection() },
    onSelect: @escaping (String, Bool) -> Void
  ) -> some View {
    overlay {
      TimelineScrubberOverlay(
        stops: stops, tint: tint, currentID: currentID,
        selectionFeedback: selectionFeedback, onSelect: onSelect)
    }
  }
}

@MainActor private struct TimelineScrubberOverlay: View {
  let stops: [TimelineScrubberStop]
  let tint: Color
  @Binding var currentID: String?
  let selectionFeedback: () -> Void
  let onSelect: (String, Bool) -> Void
  @State private var active = false
  @State private var hovering = false
  @State private var expansion: CGFloat = 0
  var body: some View {
    if !stops.isEmpty {
      TimelineScrubber(
        thresholds: stops, tint: tint,
        isActive: $active, isHovering: $hovering, targetID: $currentID,
        expansionProgress: $expansion, onSelect: onSelect,
        selectionFeedback: selectionFeedback)
    }
  }
}
