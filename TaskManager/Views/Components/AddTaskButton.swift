import SwiftUI

struct AddTaskButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("Add task")
                Image(systemName: "plus.square")
            }
            .font(.headline.weight(.regular))
            .foregroundStyle(Color.appOnDark)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appDark, in: RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityIdentifier("addTask")
    }
}

#Preview {
    AddTaskButton {}
}
