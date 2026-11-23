import SwiftUI
import Charts

struct ProductivityView: View {
    @Environment(TaskStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AuthViewModel.self) private var auth

    @State private var stats: Stats?
    @State private var errorMessage: String?

    private var settings: UserSettings { settingsStore.settings }

    // Перезавантажуємо статистику, коли змінились задачі або цілі
    private struct ReloadKey: Equatable {
        let tasks: [TaskItem]
        let dailyGoal: Int
        let weeklyGoal: Int
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("productivity.error")
                }

                if let stats {
                    todayCard(stats)
                    weekCard(stats)
                    chartCard(stats)
                    totalsCard(stats)
                } else if errorMessage == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(Color.appBackground)
        .navigationTitle("Productivity")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GoalsView()
                } label: {
                    Image(systemName: "target")
                }
                .accessibilityIdentifier("productivity.goals")
            }
        }
        .refreshable { await load() }
        .task(id: ReloadKey(tasks: store.tasks, dailyGoal: settings.dailyGoal, weeklyGoal: settings.weeklyGoal)) {
            // Перший раз вантажимо одразу. Далі — з паузою: Stepper шле PATCH на кожен тап
            if stats != nil {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
            }
            await load()
        }
    }

    private func load() async {
        do {
            let result: Stats = try await APIClient.shared.get("/stats")
            stats = result
            errorMessage = nil
        } catch APIError.unauthorized {
            auth.forceLogout()
        } catch APIError.cancelled {
            // скасовано — не помилка
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Today

    private func todayCard(_ stats: Stats) -> some View {
        let goal = settings.dailyGoal
        let progress = min(Double(stats.completedToday) / Double(max(goal, 1)), 1)

        return HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.appBorder, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progress >= 1 ? Color.green : Color.appDark,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                VStack(spacing: 0) {
                    Text("\(stats.completedToday)")
                        .font(.title2.weight(.semibold))
                    Text("of \(goal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 88, height: 88)
            .accessibilityIdentifier("productivity.todayRing")

            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.headline)
                Text(progress >= 1 ? "Daily goal reached 🎉" : "\(max(goal - stats.completedToday, 0)) more to reach your goal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if stats.streak > 0 {
                    Text("🔥 \(stats.streak) day streak")
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("productivity.streak")
                }
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    // MARK: - Week

    private func weekCard(_ stats: Stats) -> some View {
        let goal = settings.weeklyGoal

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This week")
                    .font(.headline)
                Spacer()
                Text("\(stats.completedThisWeek) / \(goal)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(stats.completedThisWeek, goal)), total: Double(max(goal, 1)))
                .tint(stats.completedThisWeek >= goal ? Color.green : Color.appDark)
        }
        .cardStyle()
    }

    // MARK: - Chart

    private func chartCard(_ stats: Stats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days")
                .font(.headline)

            Chart {
                ForEach(stats.days) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Completed", day.completed)
                    )
                    .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.indigo : Color.appDark)
                    .cornerRadius(4)
                }

                RuleMark(y: .value("Goal", settings.dailyGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(settings.dailyGoal)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .accessibilityIdentifier("productivity.chart")
        }
        .cardStyle()
    }

    // MARK: - Totals

    private func totalsCard(_ stats: Stats) -> some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                totalTile("Completed", stats.totalCompleted, color: .green)
                totalTile("In progress", stats.inProgress, color: .orange)
            }
            GridRow {
                totalTile("To-do", stats.todo, color: Color.appDark)
                totalTile("Overdue", stats.overdue, color: .red)
            }
        }
    }

    private func totalTile(_ title: String, _ value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityIdentifier("productivity.total.\(title)")
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appCard, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

#Preview {
    NavigationStack {
        ProductivityView()
    }
    .environment(TaskStore())
    .environment(SettingsStore())
    .environment(AuthViewModel())
}
