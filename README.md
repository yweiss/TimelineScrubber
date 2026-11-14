# TimelineScrubber

A SwiftUI timeline scrubber for quickly moving through long dated lists. A compact strip of ticks expands under your finger, shows a floating date label, and sends a light haptic tick as the selection changes. On Mac, it responds to pointer hover and uses available trackpad haptics.

- iPhone, iPad and Mac
- Configurable accent color for ticks and the glass date label
- Native selection haptics by default; replace or disable them
- Liquid Glass date bubble on iOS/macOS 26+, material fallback on earlier supported versions
- Accessible “Jump to…” buttons, with selection across every stop even when visible ticks are sampled
- Caller-owned scroll targets: works with photo histories, journals, activity feeds and other timelines
- No dependencies, accounts, analytics, network requests or persistent storage

Extracted from the date scrubber originally built for Memolio, then adapted for reuse in Parcel One.

## Requirements

Build with **Xcode 26+ / Swift 6+**. Deployment targets: **iOS 18+** and **macOS 15+**. Haptic output requires supported hardware and system settings; the iOS simulator does not produce physical haptics.

## Install with Xcode

1. Choose **File → Add Package Dependencies**.
2. Enter `https://github.com/yweiss/TimelineScrubber`.
3. Select version **0.1.0** or later and add the **TimelineScrubber** product to your app target.
4. Add `import TimelineScrubber` to your view.

For a Swift package, add:

```swift
// In Package.swift:
dependencies: [
    .package(url: "https://github.com/yweiss/TimelineScrubber.git", from: "0.1.0")
]

// Add to your target's dependencies:
.product(name: "TimelineScrubber", package: "TimelineScrubber")
```

## Quick start

Place the modifier on the **scrolling viewport**, inside its `ScrollViewReader`. Keep IDs stable and leave room at the trailing edge so the scrubber does not cover your content. Stops follow the supplied order; they are not automatically sorted.

```swift
import SwiftUI
import TimelineScrubber

struct TimelineExample: View {
    private let years = Array((1980...2026).reversed())
    private var stops: [TimelineScrubberStop] {
        years.map { year in
            TimelineScrubberStop(
                id: String(year), sectionID: String(year),
                date: Calendar(identifier: .gregorian).date(
                    from: DateComponents(year: year, month: 1, day: 1))!,
                label: String(year))
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(years, id: \.self) { year in
                        Text(String(year))
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, minHeight: 180,
                                   alignment: .leading)
                            .id(String(year))
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 40)
            }
            .timelineScrubber(stops: stops, tint: .orange) { id, animated in
                if animated {
                    withAnimation(.snappy) { proxy.scrollTo(id, anchor: .top) }
                } else {
                    // Keep finger tracking immediate rather than queueing animations.
                    proxy.scrollTo(id, anchor: .top)
                }
            }
        }
    }
}
```

A full copyable demo with a preview is in [Examples/TimelineExample.swift](Examples/TimelineExample.swift).

## Color and haptics

`tint` defaults to your app's `.accentColor`. For example, pass `.teal`, `.orange`, or a color from your asset catalogue. Both ticks and the floating date label use it.

Native selection feedback is enabled by default. To disable it:

```swift
.timelineScrubber(stops: stops, tint: .teal, selectionFeedback: {}) { id, _ in
    proxy.scrollTo(id, anchor: .top)
}
```

To honor an app-specific feedback preference, pass your own `selectionFeedback` closure. It runs only when the selected stop changes, and for an accessible/tapped jump. The package does not change system haptic settings.

## Advanced integration

Use `TimelineScrubber(thresholds:tint:isActive:isHovering:targetID:expansionProgress:onScrubStart:onSelect:onScrubEnd:selectionFeedback:)` directly when your app needs to hide scroll indicators during interaction, coordinate other controls with expansion, or observe drag start/end. The five binding values belong to the host. A preview/demo shows the simpler modifier API.

`TimelineScrubberStop` contains:

| Field | Meaning |
| --- | --- |
| `id` | Stable, unique identity for the stop |
| `sectionID` | ID of a view in your scroll hierarchy |
| `date` | The actual date represented by the stop |
| `label` | Your localized display text, such as “June 2024” |

`onSelect` receives a section ID and an animation hint. It sends `false` while dragging so you can scroll immediately, and `true` for direct accessible jumps. `currentID` is optional on the modifier; advanced hosts can update it as the visible section changes.

Use one stop per meaningful date or section, rather than per pixel or thumbnail. Include only real dates; a host can keep undated records outside its scrubber. For variable-height, deeply nested lazy content, ensure IDs are on the actual lazy scroll targets and test long-distance jumps—SwiftUI's estimated layout belongs to the host, not this library.

## Accessibility and platform behavior

Each visible tick has a “Jump to…” accessibility label. The date bubble honors Reduce Transparency with an opaque background. Pointer hover and cursor feedback are available on Mac. Haptics may be absent on unsupported hardware. Color and label formatting remain under the host's control.

The library is a navigation control, not a replacement for a ScrollView. It does not load photos, group dates, or infer your content order. Its trailing activation strip handles input while the rest of the overlay lets the host content remain interactive.

## Development

```sh
swift test
xcodebuild -scheme TimelineScrubber -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The package is tested independently from its host apps. Please include a minimal scrolling example, OS version and Xcode version in bug reports.

## License

MIT. See [LICENSE](LICENSE).
