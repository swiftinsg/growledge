import SwiftUI
import Charts

/// Weekly study chart: days of the week across the top, the 24 hours of the
/// day down the side (midnight at the top), and shaded bars wherever you studied.
struct HistoryView: View {
    @ObservedObject private var log: StudyLogStore
    @State private var weekOffset = 0   // 0 = this week, -1 = last week, ...

    init(log: StudyLogStore = .shared) {
        _log = ObservedObject(wrappedValue: log)
    }

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let hourLines = Array(stride(from: 0.0, through: 24.0, by: 1.0))
    private let hourLabels = Array(stride(from: 0.0, through: 24.0, by: 3.0))

    /// Weeks start on Monday.
    private var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        return c
    }

    private var weekStart: Date {
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .weekOfYear, value: weekOffset, to: thisWeek) ?? thisWeek
    }

    private var weekTitle: String {
        let end = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let format = Date.FormatStyle().month(.abbreviated).day()
        return "\(weekStart.formatted(format)) – \(end.formatted(format))"
    }

    var body: some View {
        let blocks = log.blocks(weekStarting: weekStart, calendar: calendar)
        let totalSeconds = blocks.reduce(0) { $0 + $1.seconds }

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weekPicker

                    VStack(spacing: 2) {
                        Text(durationText(totalSeconds))
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                        Text("studied this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    chart(blocks)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("History")
        }
    }

    // MARK: - Pieces

    private var weekPicker: some View {
        HStack {
            Button {
                weekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous week")

            Spacer()
            Text(weekTitle)
                .font(.headline)
            Spacer()

            Button {
                weekOffset += 1
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(weekOffset >= 0)
            .accessibilityLabel("Next week")
        }
        .padding(.horizontal, 24)
    }

    private func chart(_ blocks: [StudyBlock]) -> some View {
        // The y axis is flipped (24 - hour) so midnight sits at the top like a
        // calendar; the axis labels flip it back to real hours.
        Chart(blocks) { block in
            RectangleMark(
                x: .value("Day", dayNames[block.day]),
                yStart: .value("From", 24 - block.endHour),
                yEnd: .value("To", 24 - block.startHour),
                width: .ratio(0.8)
            )
            .foregroundStyle(.orange.gradient)
            .cornerRadius(3)
        }
        .chartXScale(domain: dayNames)
        .chartYScale(domain: 0...24)
        .chartXAxis {
            AxisMarks(position: .top, values: dayNames)
        }
        .chartYAxis {
            // a faint line for every hour
            AxisMarks(position: .leading, values: hourLines) { _ in
                AxisGridLine()
            }
            // a label every 3 hours
            AxisMarks(position: .leading, values: hourLabels) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(hourText(24 - Int(v)))
                    }
                }
            }
        }
        .frame(height: 460)
        .overlay {
            if blocks.isEmpty {
                Text("No study sessions this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Formatting

    private func hourText(_ hour: Int) -> String {
        let h = hour % 24
        let twelve = h % 12 == 0 ? 12 : h % 12
        return "\(twelve) \(h < 12 ? "AM" : "PM")"
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

#Preview {
    let cal = Calendar.current
    let monday = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    func at(_ day: Int, _ hour: Double) -> Date {
        let d = cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: monday)) ?? monday
        return d.addingTimeInterval(hour * 3600)
    }
    let sample = [
        StudySession(start: at(0, 9), end: at(0, 11)),
        StudySession(start: at(0, 14.5), end: at(0, 15.25)),
        StudySession(start: at(2, 20), end: at(2, 23.5)),
        StudySession(start: at(4, 22), end: at(5, 1))   // crosses midnight
    ]
    return HistoryView(log: StudyLogStore(previewSessions: sample))
}
