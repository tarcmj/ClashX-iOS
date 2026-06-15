import Foundation
import Combine
import UIKit

@MainActor
class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published var profiles: [Profile] = []
    @Published var activeProfile: Profile?

    private let fileManager = FileManager.default
    private let profilesDirectory: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        profilesDirectory = appSupport.appendingPathComponent("Profiles", isDirectory: true)

        if !fileManager.fileExists(atPath: profilesDirectory.path) {
            try? fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
        }

        loadProfiles()
        setupDefaultProfile()
    }

    // MARK: - Public Methods

    func importFromURL(_ urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw ProfileError.invalidURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ProfileError.invalidData
        }

        let name = url.lastPathComponent.replacingOccurrences(of: ".yaml", with: "")
            .replacingOccurrences(of: ".yml", with: "")
        try saveProfile(name: name, content: yamlString, sourceURL: urlString)
    }

    func importFromFile(url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw ProfileError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw ProfileError.invalidData
        }

        let name = url.deletingPathExtension().lastPathComponent
        try saveProfile(name: name, content: yamlString, sourceURL: url.absoluteString)
    }

    func importFromPasteboard() throws {
        guard let yamlString = UIPasteboard.general.string else {
            throw ProfileError.emptyPasteboard
        }

        let name = "Pasted \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        try saveProfile(name: name, content: yamlString, sourceURL: nil)
    }

    func activateProfile(_ profile: Profile) {
        for i in profiles.indices {
            profiles[i].isActive = profiles[i].id == profile.id
        }
        activeProfile = profiles.first(where: { $0.isActive })
        saveProfiles()
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        try? fileManager.removeItem(atPath: profile.localPath)

        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
            activeProfile?.isActive = true
        }

        saveProfiles()
    }

    func refreshRemoteProfiles() async {
        for profile in profiles where profile.sourceURL != nil {
            try? await importFromURL(profile.sourceURL!)
        }
    }

    // MARK: - Private Methods

    private func saveProfile(name: String, content: String, sourceURL: String?) throws {
        let fileName = "\(UUID().uuidString).yaml"
        let fileURL = profilesDirectory.appendingPathComponent(fileName)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let profile = Profile(
            name: name,
            localPath: fileURL.path,
            sourceURL: sourceURL
        )

        profiles.append(profile)
        saveProfiles()

        // Auto-activate first profile
        if activeProfile == nil {
            activateProfile(profile)
        }
    }

    private func loadProfiles() {
        let defaults = UserDefaults(suiteName: "group.com.clashx")
        guard let data = defaults?.data(forKey: "profiles"),
              let saved = try? JSONDecoder().decode([Profile].self, from: data) else {
            return
        }

        profiles = saved.filter { fileManager.fileExists(atPath: $0.localPath) }
        activeProfile = profiles.first(where: { $0.isActive })
    }

    private func saveProfiles() {
        let defaults = UserDefaults(suiteName: "group.com.clashx")
        if let data = try? JSONEncoder().encode(profiles) {
            defaults?.set(data, forKey: "profiles")
        }
    }

    private func setupDefaultProfile() {
        guard profiles.isEmpty else { return }

        // Create a default config file
        let defaultConfig = """
        port: 7890
        socks-port: 7891
        mixed-port: 7892
        allow-lan: false
        mode: Rule
        log-level: info
        external-controller: 127.0.0.1:9090
        proxies:
        proxy-groups:
          - name: Proxy
            type: select
            proxies:
              - DIRECT
        rules:
          - MATCH,DIRECT
        """

        let fileName = "\(UUID().uuidString).yaml"
        let fileURL = profilesDirectory.appendingPathComponent(fileName)
        try? defaultConfig.write(to: fileURL, atomically: true, encoding: .utf8)

        let defaultProfile = Profile(name: "默认配置", localPath: fileURL.path)
        profiles.append(defaultProfile)
        activateProfile(defaultProfile)
        saveProfiles()
    }

    enum ProfileError: Error, LocalizedError {
        case invalidURL
        case invalidData
        case accessDenied
        case emptyPasteboard

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的 URL"
            case .invalidData: return "无效的配置文件数据"
            case .accessDenied: return "无法访问文件"
            case .emptyPasteboard: return "剪贴板为空"
            }
        }
    }
}
