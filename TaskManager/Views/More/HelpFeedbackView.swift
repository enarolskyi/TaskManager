import SwiftUI

// TODO: заглушка
struct HelpFeedbackView: View {
    var body: some View {
        List {
            Section("Help") {
                Label("Getting started guide", systemImage: "book")
                Label("Help center", systemImage: "questionmark.circle")
                Label("Contact support", systemImage: "envelope")
                Label("Send feedback", systemImage: "bubble.left")
            }

            Section {
                EmptyView()
            } footer: {
                Text("Help & Feedback is coming soon 🚧")
            }
        }
        .foregroundStyle(.secondary)
        .navigationTitle("Help & Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        HelpFeedbackView()
    }
}
