import Testing

@testable import TimelineScrubber

@Test func boundsAndEveryDateRemainReachable() {
  #expect(TimelineScrubberIndex.index(progress: 0.5, count: 0) == nil)
  #expect(TimelineScrubberIndex.index(progress: .nan, count: 3) == nil)
  #expect(TimelineScrubberIndex.index(progress: -1, count: 3) == 0)
  #expect(TimelineScrubberIndex.index(progress: 2, count: 3) == 2)
  for count in [1, 3, 300] {
    for index in 0..<count {
      #expect(
        TimelineScrubberIndex.index(progress: (Double(index) + 0.5) / Double(count), count: count)
          == index)
    }
  }
}
