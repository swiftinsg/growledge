import SwiftUI
import Charts

/// Weekly study chart: days of the week across the top, the 24 hours of the
/// day down the side (midnight at the top), and bars wherever you studied.
/// Each bar is coloured with the colour of the subject that was studied.
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
    private var calendar: Calendar { .studyWeek }

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

    /// Time studied per subject (for the colour key under the chart).
    private struct SubjectTotal: Identifiable {
        let name: String
        let color: Color
        var seconds: TimeInterval
        var id: String { name }
    }

    /// A block with several subjects shares its time equally between them.
    private func subjectTotals(_ blocks: [StudyBlock]) -> [SubjectTotal] {
        var totals: [String: SubjectTotal] = [:]
        for block in blocks {
            let subjects = block.subjects.isEmpty
                ? [SessionSubject(name: "No subject", colorRaw: "")]
                : block.subjects
            let share = block.seconds / Double(subjects.count)
            for subject in subjects {
                totals[subject.name, default: SubjectTotal(name: subject.name, color: subject.color, seconds: 0)]
                    .seconds += share
            }
        }
        return totals.values.sorted { $0.seconds > $1.seconds }
    }

    var body: some View {
        let blocks = log.blocks(weekStarting: weekStart, calendar: calendar)
        let totalSeconds = blocks.reduce(0) { $0 + $1.seconds }

        NavigationStack {
            ZStack {
                // Same garden background as the Home tab
                AppBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        weekPicker
                            .fadeIn(order: 0)

                        VStack(spacing: 2) {
                            Text(durationText(totalSeconds))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                            Text("studied this week")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .fadeIn(order: 1)

                        subjectKey(subjectTotals(blocks))
                            .fadeIn(order: 2)

                        chart(blocks)
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .padding(.horizontal)
                            .fadeIn(order: 3)
                    }
                    .padding(.vertical)
                }
            }
            .tabFadeRoot()
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
                .font(.system(.headline, design: .rounded))
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

    /// Colour key: which colour is which subject, and how long was studied.
    @ViewBuilder
    private func subjectKey(_ totals: [SubjectTotal]) -> some View {
        if !totals.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(totals) { total in
                        HStack(spacing: 6) {
                            Circle().fill(total.color.gradient).frame(width: 10, height: 10)
                            Text(total.name)
                                .font(.subheadline.weight(.semibold))
                            Text(durationText(total.seconds))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(total.color.opacity(0.18), in: Capsule())
                        .overlay(Capsule().stroke(total.color.opacity(0.6), lineWidth: 1))
                    }
                }
                .padding(.horizontal)
            }
        }
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
            // Coloured by subject; several subjects blend into a gradient
            .foregroundStyle(block.fill)
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
        StudySession(start: at(0, 9), end: at(0, 11), subjectName: "Math", colorRaw: "blue"),
        StudySession(start: at(0, 14.5), end: at(0, 15.25), subjectName: "Science", colorRaw: "green"),
        StudySession(start: at(2, 20), end: at(2, 23.5), subjectName: "English", colorRaw: "pink"),
        StudySession(start: at(4, 22), end: at(5, 1), subjectName: "Math", colorRaw: "blue")   // crosses midnight
    ]
    return HistoryView(log: StudyLogStore(previewSessions: sample))
        .preferredColorScheme(.dark)
}
