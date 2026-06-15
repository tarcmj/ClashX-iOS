import SwiftUI

struct SettingsView: View {
    @AppStorage("darkMode") private var darkMode = false
    @State private var clashVersion = "未知"
    @State private var showingResetAlert = false

    var body: some View {
        List {
            // Appearance section
            Section("外观") {
                Toggle(isOn: $darkMode) {
                    Label("深色模式", systemImage: "moon.fill")
                }
                .onChange(of: darkMode) { _, newValue in
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        windowScene.windows.first?.overrideUserInterfaceStyle = newValue ? .dark : .unspecified
                    }
                }
            }

            // Core section
            Section("Clash 核心") {
                HStack {
                    Label("版本", systemImage: "info.circle")
                    Spacer()
                    Text(clashVersion)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    Task {
                        if let version = try? await ClashController.shared.getVersion() {
                            clashVersion = version
                        }
                    }
                }) {
                    Label("刷新版本信息", systemImage: "arrow.clockwise")
                }
            }

            // Configuration section
            Section("配置") {
                Button(action: {
                    Task {
                        await ProfileManager.shared.refreshRemoteProfiles()
                    }
                }) {
                    Label("刷新远程配置", systemImage: "arrow.triangle.2.circlepath")
                }

                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("重置所有配置", systemImage: "trash")
                }
            }

            // About section
            Section("关于") {
                HStack {
                    Label("应用名称", systemImage: "app")
                    Spacer()
                    Text("ClashX")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("平台", systemImage: "iphone")
                    Spacer()
                    Text("iOS \(UIDevice.current.systemVersion)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("构建版本", systemImage: "hammer")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }

            // Links
            Section("链接") {
                Link(destination: URL(string: "https://github.com/Dreamacro/clash")!) {
                    Label("Clash 核心", systemImage: "link")
                }

                Link(destination: URL(string: "https://altstore.io")!) {
                    Label("AltStore 侧载指南", systemImage: "link")
                }
            }
        }
        .navigationTitle("设置")
        .alert("重置配置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) {
                // Reset all stored data
                let defaults = UserDefaults(suiteName: "group.com.clashx")
                defaults?.removeObject(forKey: "profiles")
                // Clear profiles directory
                // Reload
            }
        } message: {
            Text("此操作将清除所有配置文件和设置，确定继续？")
        }
        .task {
            if let version = try? await ClashController.shared.getVersion() {
                clashVersion = version
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}
