import SwiftUI

struct CalendarView: View {
    @Environment(TaskStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore

    @State private var selectedDate = Date.now
    @State private var isShowingDatePicker = false
    @State private var isShowingNewTask = false

    // firstWeekday залежить від налаштування Start week on
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = settingsStore.settings.weekStart == .monday ? 2 : 1
        return calendar
    }

    private var weekDays: [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start else {
            return []
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    // Невиконані зверху
    private var tasksForSelectedDay: [TaskItem] {
        store.tasks
            .filter { calendar.isDate($0.dueDate, inSameDayAs: selectedDate) }
            .sorted { ($0.status == .done ? 1 : 0, $0.id) < ($1.status == .done ? 1 : 0, $1.id) }
    }

    private var dayTitle: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                header
                monthBar
                weekStrip
                taskList
            }

            AddTaskButton { isShowingNewTask = true }
                .padding(20)
        }
        .background(Color.appBackground)
        // Якщо календар відкрили раніше за Plan
        .task {
            if store.tasks.isEmpty { await store.load() }
        }
        .sheet(isPresented: $isShowingDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $isShowingNewTask) {
            TaskFormView(mode: .create(initialDate: selectedDate))
                .environment(store)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.wide).day()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(dayTitle)
                .font(.system(size: 30))
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Month bar

    private var monthBar: some View {
        HStack {
            Button {
                isShowingDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(Color.appDark)
            }
            .accessibilityIdentifier("calendar.month")

            Spacer()

            HStack(spacing: 20) {
                // Стрілки — крок на день, свайп по тижню — на тиждень
                Button { shiftDay(by: -1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityIdentifier("calendar.prevDay")

                Button("Today") {
                    withAnimation { selectedDate = .now }
                }
                .font(.subheadline)
                .accessibilityIdentifier("calendar.today")

                Button { shiftDay(by: 1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityIdentifier("calendar.nextDay")
            }
            .foregroundStyle(Color.appDark)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    // MARK: - Week strip

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(day)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .simultaneousGesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -30 { shiftWeek(by: 1) }
                if value.translation.width > 30 { shiftWeek(by: -1) }
            }
        )
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasTasks = store.tasks.contains { calendar.isDate($0.dueDate, inSameDayAs: day) }

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedDate = day }
        } label: {
            VStack(spacing: 10) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                Text(day.formatted(.dateTime.day()))
                    .fontWeight(isToday ? .bold : .regular)
                // Є задачі на цей день
                Circle()
                    .fill(hasTasks ? (isSelected ? Color.appOnDark : Color.appDark) : .clear)
                    .frame(width: 5, height: 5)
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? Color.appOnDark : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule().fill(Color.appDark)
                }
            }
            .padding(.horizontal, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("calendar.day.\(day.formatted(.dateTime.day()))")
    }

    // MARK: - Tasks

    @ViewBuilder
    private var taskList: some View {
        let tasks = tasksForSelectedDay

        if store.isLoading && store.tasks.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            Spacer()
        } else if tasks.isEmpty {
            ScrollView {
                EmptyStateView(icon: "calendar.badge.checkmark",
                               title: "No tasks for this day",
                               subtitle: "Enjoy your free time or add a new task")
            }
            .refreshable { await store.load() }
        } else {
            TaskListView(tasks: tasks)
                .refreshable { await store.load() }
        }
    }

    // MARK: - Date picker

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker("Select date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.calendar, calendar)
                    .tint(Color.appDark)
                    .padding()
                Spacer()
            }
            .navigationTitle("Choose date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func shiftDay(by days: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        }
    }

    private func shiftWeek(by weeks: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDate) ?? selectedDate
        }
    }
}

#Preview {
    CalendarView()
        .environment(TaskStore())
        .environment(SettingsStore())
}
