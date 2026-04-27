import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String = UserProfileStore.displayName()
    @State private var birthday: Date = UserProfileStore.birthday() ?? Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    @State private var saveMessage: String?

    private let settings = RegulationSettingsStore()

    private var textPrimary: Color { colorScheme == .dark ? Color.white.opacity(0.96) : Color.black.opacity(0.88) }
    private var textSecondary: Color { colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.68) }
    private var textMuted: Color { colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.56) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    profileIdentityCard
                    achievementsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(RespiteDynamicBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your profile")
                .font(.system(size: 30, weight: .semibold, design: .default))
                .foregroundStyle(textPrimary)
            Text("Customize your identity and track your progress milestones.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)
        }
    }

    private var profileIdentityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Identity")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            HStack(spacing: 14) {
                profilePhoto

                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile photo")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundStyle(textPrimary)
                    Text("Photo uploads are disabled.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(textMuted)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)

                TextField("Your name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundStyle(textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Birthday")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)

                DatePicker("", selection: $birthday, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(RespiteTheme.duskBlue)
            }

            Button("Save profile") {
                UserProfileStore.setDisplayName(name)
                UserProfileStore.setBirthday(birthday)
                name = UserProfileStore.displayName()
                saveMessage = "Profile saved."
            }
            .font(.system(size: 14, weight: .semibold, design: .default))
            .buttonStyle(.borderedProminent)
            .tint(RespiteTheme.duskBlue)

            if let saveMessage {
                Text(saveMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(textMuted)
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var profilePhoto: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 86, height: 86)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(textMuted)
        }
    }

    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(textSecondary)

            ForEach(achievementItems) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.unlocked ? "checkmark.seal.fill" : "lock.fill")
                        .foregroundStyle(item.unlocked ? RespiteTheme.sageLight : textMuted)
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundStyle(textPrimary)
                        Text(item.detail)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(textMuted)
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .respiteGlassCard(cornerRadius: 20)
    }

    private var achievementItems: [ProfileAchievement] {
        let todayMinutes = DailyProgressStore.minutesSavedToday()
        let streakDays = DailyProgressStore.currentStreak(goalMinutes: settings.streakGoalMinutes)
        let reflectionCount = ReflectionStore.allEntries().count

        return [
            ProfileAchievement(
                title: "Focused Start",
                detail: "Save at least 30 minutes in one day.",
                unlocked: todayMinutes >= 30
            ),
            ProfileAchievement(
                title: "Streak Keeper",
                detail: "Hit your daily goal for 3 days in a row.",
                unlocked: streakDays >= 3
            ),
            ProfileAchievement(
                title: "Reflective Mind",
                detail: "Write 5 reflections.",
                unlocked: reflectionCount >= 5
            )
        ]
    }
}

private struct ProfileAchievement: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let unlocked: Bool
}
