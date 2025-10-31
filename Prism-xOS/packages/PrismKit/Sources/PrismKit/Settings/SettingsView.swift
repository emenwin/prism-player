import SwiftUI

/// 设置页面视图（占位实现）
/// Settings view (placeholder implementation)
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                // MARK: - 关于部分
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(
                            String(localized: "settings.about.title"),
                            systemImage: "info.circle"
                        )
                    }
                } header: {
                    Text(String(localized: "settings.section.about"))
                }

                // MARK: - 许可证部分
                Section {
                    NavigationLink {
                        LicensesPlaceholderView()
                    } label: {
                        Label(
                            String(localized: "settings.licenses.title"),
                            systemImage: "doc.text"
                        )
                    }

                    NavigationLink {
                        ModelLicensesPlaceholderView()
                    } label: {
                        Label(
                            String(localized: "settings.modelLicenses.title"),
                            systemImage: "brain"
                        )
                    }
                } header: {
                    Text(String(localized: "settings.section.licenses"))
                }

                // MARK: - 隐私部分
                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(
                            String(localized: "settings.privacy.title"),
                            systemImage: "hand.raised"
                        )
                    }
                } header: {
                    Text(String(localized: "settings.section.privacy"))
                }
            }
            .navigationTitle(String(localized: "settings.title"))
        }
    }
}

// MARK: - 关于视图

struct AboutView: View {
    var body: some View {
        List {
            Section {
                HStack {
                    Text(String(localized: "settings.about.appName"))
                    Spacer()
                    Text(String(localized: "app.name"))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "settings.about.version"))
                    Spacer()
                    Text("0.1.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(String(localized: "settings.about.buildNumber"))
                    Spacer()
                    Text("1")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Link(destination: URL(string: "https://github.com/prism-player")!) {
                    HStack {
                        Label(
                            String(localized: "settings.about.github"),
                            systemImage: "chevron.left.forwardslash.chevron.right"
                        )
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "settings.about.title"))
    }
}

// MARK: - 开源许可证占位视图

struct LicensesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(String(localized: "settings.licenses.title"))
                .font(.headline)

            Text(String(localized: "settings.licenses.comingSoon"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(String(localized: "settings.licenses.placeholder.description"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .navigationTitle(String(localized: "settings.licenses.title"))
    }
}

// MARK: - 模型许可证占位视图

struct ModelLicensesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(String(localized: "settings.modelLicenses.title"))
                .font(.headline)

            Text(String(localized: "settings.licenses.comingSoon"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(String(localized: "settings.modelLicenses.placeholder.description"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .navigationTitle(String(localized: "settings.modelLicenses.title"))
    }
}

// MARK: - 隐私政策视图

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "settings.privacy.statement"))
                    .font(.headline)

                Text(String(localized: "settings.privacy.dataCollection.title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(String(localized: "settings.privacy.dataCollection.description"))
                    .font(.body)
                    .foregroundStyle(.secondary)

                Text(String(localized: "settings.privacy.permissions.title"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    PermissionRow(
                        icon: "mic.fill",
                        title: String(localized: "permission.microphone.title"),
                        description: String(localized: "permission.microphone.description")
                    )

                    PermissionRow(
                        icon: "photo.fill",
                        title: String(localized: "permission.mediaLibrary.title"),
                        description: String(localized: "permission.mediaLibrary.description")
                    )

                    PermissionRow(
                        icon: "waveform",
                        title: String(localized: "permission.speechRecognition.title"),
                        description: String(localized: "permission.speechRecognition.description")
                    )
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: "settings.privacy.title"))
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Settings") {
    SettingsView()
}

#Preview("About") {
    NavigationStack {
        AboutView()
    }
}

#Preview("Licenses Placeholder") {
    NavigationStack {
        LicensesPlaceholderView()
    }
}

#Preview("Model Licenses Placeholder") {
    NavigationStack {
        ModelLicensesPlaceholderView()
    }
}

#Preview("Privacy Policy") {
    NavigationStack {
        PrivacyPolicyView()
    }
}
