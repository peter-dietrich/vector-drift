import AppKit
import SwiftUI

// Native, entirely offline help book. This does not intercept gameplay keys,
// mutate saves, or require a browser, internet connection or account.
private struct HelpRow: Identifiable {
    let id = UUID()
    let key: String
    let action: String
}
private enum HelpPage: String, CaseIterable {
    case overview, controls, progress
    var title: String {
        switch self {
        case .overview: return "How to Play"
        case .controls: return "Controls & Shortcuts"
        case .progress: return "Scores & Saving"
        }
    }
}

private enum GameHelpContent {
    static let title = "Vector Drift"
    static let tagline = "Arcade space combat — Classic, Modern and 3D Flight"
    static let overview = "Survive waves of asteroids, saucers and environmental hazards while managing shields and weapons. Choose Classic, Modern, or 3D Flight and difficulty from the in-game toolbar."
    static let progress = "Custom rules, saved games and score records are stored locally, not in GitHub. Use the in-game Save Game and Resume commands; switching display modes does not upload your progress."
    static let controls: [HelpRow] = [
        HelpRow(key: "Return", action: "Start or restart from title or game-over screen."),
        HelpRow(key: "Left / Right", action: "Turn or yaw."),
        HelpRow(key: "Up", action: "Thrust forward."),
        HelpRow(key: "Down", action: "Hyperspace in 2D; reverse in 3D Flight."),
        HelpRow(key: "Space", action: "Fire weapon."),
        HelpRow(key: "S", action: "Shield."),
        HelpRow(key: "N", action: "Launch available special missile."),
        HelpRow(key: "P", action: "Pause or resume."),
        HelpRow(key: "3D Flight: I/K, Q/E", action: "Pitch; roll."),
        HelpRow(key: "3D Flight: W/X, A/D", action: "Rise/dive; strafe.")
    ]
}

@MainActor
private enum GameHelpPanel {
    private static var helpWindow: NSWindow?

    static func show(_ page: HelpPage = .overview) {
        let view = HelpBookView(page: page)
        if let existing = helpWindow {
            existing.contentView = NSHostingView(rootView: view)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = GameHelpContent.title + " Help"
        window.minSize = NSSize(width: 530, height: 420)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: view)
        helpWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct HelpBookView: View {
    @State var page: HelpPage
    private let amber = Color(red: 1, green: 0.67, blue: 0.29)
    private let navy = Color(red: 0.035, green: 0.045, blue: 0.09)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(GameHelpContent.title.uppercased())
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white)
                    Text(GameHelpContent.tagline)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(amber)
                }
                Spacer()
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(amber)
                    .accessibilityHidden(true)
            }
            .padding(24)
            Picker("Help topic", selection: $page) {
                ForEach(HelpPage.allCases, id: \.self) { topic in
                    Text(topic.title).tag(topic)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text(page.title.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(amber)
                    switch page {
                    case .overview:
                        Text(GameHelpContent.overview)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Open Controls & Shortcuts for the keys used by this game. The game window may need keyboard focus.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.65))
                    case .controls:
                        ForEach(GameHelpContent.controls) { row in
                            HStack(alignment: .top, spacing: 18) {
                                Text(row.key)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(amber)
                                    .frame(width: 210, alignment: .leading)
                                Text(row.action)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 5)
                            Divider().overlay(.white.opacity(0.08))
                        }
                    case .progress:
                        Text(GameHelpContent.progress)
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("LOCAL FIRST  ·  NO ACCOUNT REQUIRED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(amber)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 530, minHeight: 420)
        .background(navy)
        .preferredColorScheme(.dark)
    }
}

struct GameHelpCommands: Commands {
    var body: some Commands {
        CommandMenu("Game") {
            Button("How to Play…") { GameHelpPanel.show(.overview) }
            Button("Controls & Shortcuts…") { GameHelpPanel.show(.controls) }
            Divider()
            Button("Scores & Saving…") { GameHelpPanel.show(.progress) }
        }
        CommandGroup(replacing: .help) {
            Button(GameHelpContent.title + " Help") { GameHelpPanel.show(.overview) }
                .keyboardShortcut("?", modifiers: .command)
            Button("Keyboard Controls…") { GameHelpPanel.show(.controls) }
            Button("Saved Games & Scores…") { GameHelpPanel.show(.progress) }
        }
    }
}
