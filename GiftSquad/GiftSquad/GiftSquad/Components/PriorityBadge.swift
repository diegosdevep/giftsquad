import SwiftUI

struct PriorityBadge: View {
    let priority: ItemPriority

    var body: some View {
        Text(priority.label)
            .font(GSFont.caption(10))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priority.color.opacity(0.14))
            .foregroundStyle(priority.color)
            .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        PriorityBadge(priority: .low)
        PriorityBadge(priority: .medium)
        PriorityBadge(priority: .high)
    }
}
