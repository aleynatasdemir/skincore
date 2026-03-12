import SwiftUI
import UIKit

struct AvatarView: View {
    let name: String

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first
        let second = parts.dropFirst().first?.first
        return String([first, second].compactMap { $0 }).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "F3D5DC"))
                .frame(width: 38, height: 38)
            Text(initials.isEmpty ? "S" : initials)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "9A4C5E"))
        }
    }
}

struct WrapTags: View {
    let tags: [String]

    var body: some View {
        FlexibleView(data: tags, spacing: 8, alignment: .leading) { tag in
            Text(tag)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(hex: "F7E9EC"))
                .foregroundColor(Color(hex: "9A4C5E"))
                .cornerRadius(10)
        }
    }
}

func timeAgo(_ isoString: String?) -> String {
    guard let isoString else { return "" }

    let formatterWithFraction = ISO8601DateFormatter()
    formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let formatter = ISO8601DateFormatter()

    let date = formatterWithFraction.date(from: isoString) ?? formatter.date(from: isoString)
    guard let date else { return "" }

    let rel = RelativeDateTimeFormatter()
    rel.unitsStyle = .short
    return rel.localizedString(for: date, relativeTo: Date())
}

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    @State private var availableWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { availableWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { availableWidth = $0 }
            }
        )
    }

    private func computeRows() -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentWidth: CGFloat = 0

        for item in data {
            let itemWidth = textWidth(for: item) + spacing
            if currentWidth + itemWidth > availableWidth, !rows[rows.count - 1].isEmpty {
                rows.append([item])
                currentWidth = itemWidth
            } else {
                rows[rows.count - 1].append(item)
                currentWidth += itemWidth
            }
        }

        return rows
    }

    private func textWidth(for item: Data.Element) -> CGFloat {
        let label = UILabel()
        label.text = "\(item)"
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.sizeToFit()
        return label.frame.width + 20
    }
}
