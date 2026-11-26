import SwiftUI

struct GroupIconPicker: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(GroupIcon.catalog, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Image(systemName: option)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selection == option ? GSPalette.oceano : GSPalette.noche)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selection == option ? GSPalette.oceano.opacity(0.14) : Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    selection == option ? GSPalette.oceano : GSPalette.grafito.opacity(0.15),
                                    lineWidth: selection == option ? 2 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
