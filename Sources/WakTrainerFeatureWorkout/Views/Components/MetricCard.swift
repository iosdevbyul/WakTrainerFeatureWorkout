import SwiftUI

internal struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let iconName: String
    let iconColor: Color
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 8) {
            Image(systemName: iconName)
                .font(compact ? .body : .title2)
                .foregroundStyle(iconColor)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !compact { Spacer(minLength: 0) }

            Text(value)
                .font(compact ? .headline.bold() : .title2.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(compact ? 9 : 14)
        .frame(height: compact ? 108 : nil)
        .modifier(MetricCardSquareWhenExpanded(compact: compact))
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct MetricCardSquareWhenExpanded: ViewModifier {
    let compact: Bool
    func body(content: Content) -> some View {
        if compact { content } else { content.aspectRatio(1, contentMode: .fit) }
    }
}
