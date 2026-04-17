import Foundation

/// Configuration for the “one tap” TikTok + Shortcuts onboarding flow.
///
/// **Platform note:** iOS does not allow third-party apps to create or enable Personal Automations silently.
/// The closest match to apps like One Sec is a **shared iCloud link** to a pre-built automation; the user still taps **Add** once in Shortcuts.
///
/// **Maintainer:** In Shortcuts, build the Personal Automation (When TikTok is opened → “Calm breathing before TikTok” / “Calm breathing then TikTok” with **Open TikTok when done** on),
/// then use the share sheet’s **Copy iCloud Link** (or equivalent) and paste the full `https://www.icloud.com/shortcuts/...` URL into `prebuiltPersonalAutomationShareURLString` before release.
enum RespiteTikTokShortcutSetup {
    static let prebuiltPersonalAutomationShareURLString: String? = nil

    static var prebuiltPersonalAutomationShareURL: URL? {
        guard let raw = prebuiltPersonalAutomationShareURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http"
        else { return nil }
        return url
    }

    static var hasPrebuiltShareLink: Bool { prebuiltPersonalAutomationShareURL != nil }
}
