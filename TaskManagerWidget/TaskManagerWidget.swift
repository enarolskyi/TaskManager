import WidgetKit
import SwiftUI

// MARK: - Timeline

struct TaskEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?

    // "Сьогодні" рахуємо від дати запису, а не від моменту, коли застосунок зберіг дані
    var overdue: [WidgetSnapshot.Item] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return (snapshot?.items ?? []).filter { $0.dueDate < startOfDay }
    }

    var today: [WidgetSnapshot.Item] {
        (snapshot?.items ?? []).filter { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }
    }

    /// Спершу прострочені, потім сьогоднішні за пріоритетом
    var visibleItems: [WidgetSnapshot.Item] {
        overdue + today.sorted { rank($0.priority) < rank($1.priority) }
    }

    private func rank(_ priority: String) -> Int {
        switch priority {
        case "high": 0
        case "medium": 1
        default: 2
        }
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        // У галереї віджетів показуємо приклад, щоб було видно, як він виглядає
        completion(TaskEntry(date: .now, snapshot: context.isPreview ? WidgetSnapshot.sample : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date.now
        let midnight = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))

        // Другий запис опівночі — щоб "сьогодні" і прострочені перерахувались без відкриття застосунку
        let entries = [
            TaskEntry(date: now, snapshot: snapshot),
            TaskEntry(date: midnight, snapshot: snapshot),
        ]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Views

struct TaskManagerWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TaskEntry

    var body: some View {
        if entry.snapshot?.isLoggedIn != true {
            loggedOut
        } else if family == .systemSmall {
            small
        } else {
            medium
        }
    }

    private var loggedOut: some View {
        VStack(spacing: 6) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.title2)
            Text("Log in to see your tasks")
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            Spacer(minLength: 0)
            Text("\(entry.today.count)")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
            Text(entry.today.count == 1 ? "task today" : "tasks today")
                .font(.caption)
                .foregroundStyle(.secondary)
            overdueLabel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                header
                Spacer(minLength: 0)
                Text("\(entry.today.count)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                Text(entry.today.count == 1 ? "task today" : "tasks today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                overdueLabel
            }
            .frame(width: 96, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if entry.visibleItems.isEmpty {
                    Spacer()
                    Text("Nothing planned for today 🎉")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    ForEach(entry.visibleItems.prefix(4), id: \.self) { item in
                        row(item)
                    }
                    if entry.visibleItems.count > 4 {
                        Text("+\(entry.visibleItems.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "checklist")
            Text("Today")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var overdueLabel: some View {
        if !entry.overdue.isEmpty {
            Text("\(entry.overdue.count) overdue")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.red)
        }
    }

    private func row(_ item: WidgetSnapshot.Item) -> some View {
        let isOverdue = item.dueDate < Calendar.current.startOfDay(for: entry.date)
        return HStack(spacing: 6) {
            Circle()
                .fill(priorityColor(item.priority))
                .frame(width: 7, height: 7)
            Text(item.title)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(isOverdue ? Color.red : Color.primary)
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "high": .red
        case "medium": .orange
        default: .green
        }
    }
}

// MARK: - Widget

struct TaskManagerWidget: Widget {
    let kind = "TaskManagerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            TaskManagerWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's tasks")
        .description("Tasks due today and overdue ones.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    TaskManagerWidget()
} timeline: {
    TaskEntry(date: .now, snapshot: .sample)
}

#Preview(as: .systemMedium) {
    TaskManagerWidget()
} timeline: {
    TaskEntry(date: .now, snapshot: .sample)
    TaskEntry(date: .now, snapshot: WidgetSnapshot(isLoggedIn: true, items: [], updatedAt: .now))
    TaskEntry(date: .now, snapshot: nil)
}
