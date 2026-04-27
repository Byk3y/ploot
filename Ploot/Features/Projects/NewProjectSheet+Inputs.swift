import SwiftUI

// Section views NewProjectSheet's body composes — preview card, name
// field, emoji grid (with the trailing "any emoji" tile), and tile-
// color swatch row. Pulled out so the main file can stay focused on
// state, body wiring, and submit.

extension NewProjectSheet {

    // MARK: - Live preview

    var previewCard: some View {
        HStack(spacing: Spacing.s3) {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tileColor.fill(palette: palette))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.borderInk, lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Your project" : name)
                    .font(.geist(size: 16, weight: 600))
                    .tracking(-0.005 * 16)
                    .foregroundStyle(name.isEmpty ? palette.fg3 : palette.fg1)
                Text("0 open · 0 done")
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(palette.fg3)
            }
            Spacer(minLength: 0)
        }
        .cardStyle(radius: Radius.lg, padding: 14)
    }

    // MARK: - Name

    var nameField: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("name")
                .eyebrow()
                .foregroundStyle(palette.fg3)

            TextField("What's it called?", text: $name)
                .font(.fraunces(size: 22, weight: 500, opsz: 22, soft: 50))
                .foregroundStyle(palette.fg1)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit(submit)
                .padding(.vertical, Spacing.s3)
                .padding(.horizontal, Spacing.s3)
                .background(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(nameFocused ? palette.borderInk : palette.border, lineWidth: 2)
                )
        }
    }

    // MARK: - Emoji

    var emojiSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("emoji")
                .eyebrow()
                .foregroundStyle(palette.fg3)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s2), count: 5),
                spacing: Spacing.s2
            ) {
                ForEach(emojiSuggestions, id: \.self) { candidate in
                    emojiTile(candidate)
                }
                moreEmojiTile
            }
        }
    }

    /// The tenth tile. If the user has picked a custom emoji (one not in
    /// `emojiSuggestions`) it's shown here with selected-tile styling;
    /// otherwise a face.smiling icon hints that tapping opens the emoji
    /// keyboard. The EmojiTextField sits invisibly on top and catches
    /// taps — becoming first responder triggers the native picker.
    var moreEmojiTile: some View {
        let isCustom = !emojiSuggestions.contains(emoji) && !emoji.isEmpty
        return ZStack {
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(isCustom ? palette.primary.opacity(0.18) : palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(isCustom ? palette.primary : palette.border, lineWidth: 2)
                )

            EmojiTextField(text: $emoji, hidesCursor: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Group {
                if isCustom {
                    Text(emoji).font(.system(size: 24))
                } else {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(palette.fg3)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .sensoryFeedback(.selection, trigger: emoji)
    }

    func emojiTile(_ candidate: String) -> some View {
        let selected = emoji == candidate
        return Button {
            withAnimation(Motion.springFast) { emoji = candidate }
        } label: {
            Text(candidate)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .fill(selected ? palette.primary.opacity(0.18) : palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(selected ? palette.primary : palette.border, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }

    // MARK: - Color

    var colorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            Text("tile color")
                .eyebrow()
                .foregroundStyle(palette.fg3)

            HStack(spacing: Spacing.s2) {
                ForEach(colorOptions, id: \.self) { candidate in
                    colorSwatch(candidate)
                }
                Spacer(minLength: 0)
            }
        }
    }

    func colorSwatch(_ candidate: ProjectTileColor) -> some View {
        let selected = tileColor == candidate
        return Button {
            withAnimation(Motion.springFast) { tileColor = candidate }
        } label: {
            Circle()
                .fill(candidate.fill(palette: palette))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle().strokeBorder(palette.borderInk, lineWidth: 2)
                )
                .background(
                    Circle()
                        .fill(palette.borderInk)
                        .offset(y: selected ? 0 : 2)
                )
                .offset(y: selected ? 2 : 0)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(palette.borderInk)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
    }
}
