#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

/// Native selection feedback is enabled by default. Pass `selectionFeedback: {}`
/// to disable it, or supply a closure to integrate your app's feedback settings.
@MainActor public enum TimelineScrubberFeedback {
  public static func selection() {
    #if os(iOS)
      UISelectionFeedbackGenerator().selectionChanged()
    #elseif os(macOS)
      NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
  }
}
