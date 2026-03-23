import SwiftUI
import NukeUI

/// A circular headshot card for cast and crew display.
/// Netflix/HBO style: clean circular photo with name and role below.
struct CastCard: View {
    let person: PersonInfo

    @Environment(\.isFocused) private var isFocused

    private let imageSize: CGFloat = 130

    var body: some View {
        VStack(spacing: 10) {
            // Circular headshot
            ZStack {
                // Glow ring on focus
                Circle()
                    .fill(Color.white.opacity(isFocused ? 0.15 : 0))
                    .frame(width: imageSize + 8, height: imageSize + 8)

                LazyImage(url: personImageURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        initialsPlaceholder
                    }
                }
                .frame(width: imageSize, height: imageSize)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isFocused ? 0.4 : 0.1), lineWidth: 2)
                )
            }

            // Name
            Text(person.name ?? "Unknown")
                .font(.system(size: LumaTheme.captionSize, weight: .medium))
                .foregroundColor(isFocused ? .white : LumaTheme.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            // Role
            if let role = person.role, !role.isEmpty {
                Text(role)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(LumaTheme.textTertiary)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: imageSize + 30)
        .scaleEffect(isFocused ? 1.08 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    // MARK: - Private

    private var personImageURL: URL? {
        guard let id = person.id else { return nil }
        return ImageURLBuilder.personImageURL(
            personId: id,
            tag: person.primaryImageTag,
            maxWidth: Int(imageSize * 2)
        )
    }

    private var initialsPlaceholder: some View {
        Circle()
            .fill(LumaTheme.cardSurface)
            .overlay {
                Text(initials)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(LumaTheme.textTertiary)
            }
    }

    private var initials: String {
        guard let name = person.name else { return "?" }
        let components = name.split(separator: " ")
        let first = components.first?.prefix(1) ?? ""
        let last = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}
