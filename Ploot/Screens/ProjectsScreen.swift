import SwiftUI

struct ProjectsScreen: View {
    @Bindable var store: TaskStore

    @Environment(\.plootPalette) private var palette

    var body: some View {
        ScreenFrame(
            title: "Projects",
            subtitle: "Where the plans live.",
            trailing: {
                HeaderButton(systemImage: "plus", action: {})
            },
            content: {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(store.projects) { project in
                            ProjectCard(project: project)
                        }
                        Color.clear.frame(height: 120)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s2)
                }
            }
        )
    }
}

private struct ProjectCard: View {
    let project: PlootProject

    @Environment(\.plootPalette) private var palette

    var body: some View {
        let total = project.openCount + project.doneCount
        let pct = total == 0 ? 0 : Double(project.doneCount) / Double(total)

        VStack(alignment: .leading, spacing: Spacing.s3) {
            HStack(spacing: Spacing.s3) {
                Text(project.emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(project.tileColor.fill(palette: palette))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(palette.borderInk, lineWidth: 2)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.geist(size: 16, weight: 600))
                        .tracking(-0.005 * 16)
                        .foregroundStyle(palette.fg1)

                    HStack(spacing: Spacing.s2) {
                        Text("\(project.openCount) open")
                        Circle().fill(palette.fg3).frame(width: 3, height: 3)
                        Text("\(project.doneCount) done")
                    }
                    .font(.geist(size: 13, weight: 400))
                    .foregroundStyle(palette.fg3)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.fg3)
            }

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.bgSunken)
                    Capsule()
                        .fill(project.tileColor.dot(palette: palette))
                        .frame(width: pct * geo.size.width)
                }
            }
            .frame(height: 5)
        }
        .cardStyle(radius: Radius.lg, padding: 14)
    }
}
