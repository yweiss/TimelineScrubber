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
              .frame(
                maxWidth: .infinity, minHeight: 180,
                alignment: .leading
              )
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

#Preview { TimelineExample() }
