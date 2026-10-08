import SwiftUI

internal struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let iconName: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .aspectRatio(1, contentMode: .fit)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
