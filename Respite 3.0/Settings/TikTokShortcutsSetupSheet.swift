import SwiftUI

/// Explains the iOS Shortcuts constraint and offers a pre-built import link (when configured) or manual steps.
struct TikTokShortcutsSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Apple doesn’t let apps turn on Shortcuts automations for you. A single Add or Done in Shortcuts is normal—even when a flow feels pre-installed, like other apps.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Text("If Shortcuts shows “Opening breathwork” and never finishes, you’re probably using Open URL regulate://breathwork (Screen Time breathwork). That is not the same as “Calm breathing before TikTok.” Remove the deep link and use only the Respite App Intent so the automation completes when you tap Continue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    if let url = RespiteTikTokShortcutSetup.prebuiltPersonalAutomationShareURL {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Add pre-built automation", systemImage: "link.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text("Opens your link in Shortcuts. Confirm Add, then turn the automation on if asked.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("The App Store build can include a share link here so you skip building steps by hand. Until that link is configured, use manual setup below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("Manual setup") {
                        manualSteps
                            .padding(.top, 8)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("TikTok calm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var manualSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended — single step (like One Sec)")
                .font(.subheadline.weight(.semibold))
            Group {
                Text("1. Shortcuts → Automation → + → Personal Automation.")
                Text("2. Trigger: App → Is Opened → TikTok.")
                Text("3. Add “Calm breathing then TikTok” or “Run TikTok breathing gate” (Respite).")
                Text("4. Turn “Open TikTok when done” on. No separate Open URL step.")
                Text("5. Banners: if Notify When Run and the action’s Show When Run are already off and you still see a sheet (e.g. “Opening …”), that’s iOS for App Intent / app handoff. There is no other Shortcuts toggle and third-party apps cannot turn it off—only Apple could change that in a future OS.")
                Text("6. Open Respite once after installing so Shortcuts lists its actions.")
            }

            Text("Two-step (advanced)")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)
            Group {
                Text("Same trigger; add “Run TikTok breathing gate” with “Open TikTok when done” off, then Open URL tiktok://")
            }

            Text("Legacy")
                .font(.subheadline.weight(.semibold))
                .padding(.top, 8)
            Text("“Is TikTok handoff suppress active” → If true (empty) → Otherwise Open URL regulate://tiktok-breath (or regulate://breathwork).")

            Text("Requires iOS 26+ for Respite’s Shortcuts actions.")
                .padding(.top, 8)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
