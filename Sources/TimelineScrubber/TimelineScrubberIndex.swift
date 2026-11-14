import Foundation

public enum TimelineScrubberIndex {
  /// Maps a vertical fraction to the original caller-supplied ordering, newest or oldest first.
  public static func index(progress: Double, count: Int) -> Int? {
    guard count > 0, progress.isFinite else { return nil }
    return min(Int(max(0, min(1, progress)) * Double(count)), count - 1)
  }
}
