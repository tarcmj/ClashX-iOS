import SwiftUI

struct ProxyView: View {
    @State private var proxyGroups: [ProxyGroup] = []
    @State private var isLoading = true
    @State private var testingProxy: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载代理...")
            } else if proxyGroups.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("没有代理组")
                        .font(.headline)
                    Text("请确保 Clash 已连接且有有效配置")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(proxyGroups) { group in
                        Section(header: Text(group.name)) {
                            Text(group.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if group.type == .select || group.type == .relay {
                                Picker("选择节点", selection: Binding(
                                    get: { group.now ?? group.all.first ?? "" },
                                    set: { newValue in
                                        Task {
                                            try? await ClashController.shared.selectProxy(
                                                groupName: group.name,
                                                proxyName: newValue
                                            )
                                            await loadProxies()
                                        }
                                    }
                                )) {
                                    ForEach(group.all, id: \.self) { proxy in
                                        HStack {
                                            Text(proxy)
                                            if proxy == group.now {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                        .tag(proxy)
                                    }
                                }
                                .pickerStyle(.menu)
                            } else {
                                ForEach(group.all, id: \.self) { proxy in
                                    HStack {
                                        Text(proxy)
                                        Spacer()
                                        if testingProxy == proxy {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            // Delay info placeholder
                                            Text("--")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }

                            // Delay test button
                            Button(action: {
                                Task {
                                    await testAllDelays(for: group)
                                }
                            }) {
                                Label("延迟测试", systemImage: "bolt.horizontal")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("代理")
        .refreshable {
            await loadProxies()
        }
        .task {
            await loadProxies()
        }
    }

    private func loadProxies() async {
        isLoading = true
        defer { isLoading = false }

        let controller = ClashController.shared
        guard await controller.isReachable() else {
            errorMessage = "Clash 核心未连接"
            return
        }

        do {
            let proxiesData = try await controller.getProxies()
            var groups: [ProxyGroup] = []

            for (name, data) in proxiesData {
                if let dict = data as? [String: Any],
                   let type = dict["type"] as? String {
                    let all = dict["all"] as? [String] ?? []
                    let now = dict["now"] as? String

                    let group = ProxyGroup(
                        name: name,
                        type: ProxyGroup.GroupType(rawValue: type) ?? .unknown,
                        now: now,
                        all: all
                    )
                    groups.append(group)
                }
            }

            proxyGroups = groups.sorted { $0.name < $1.name }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func testAllDelays(for group: ProxyGroup) async {
        let controller = ClashController.shared
        for proxy in group.all {
            testingProxy = proxy
            _ = try? await controller.delayTest(proxyName: proxy)
        }
        testingProxy = nil
    }
}

#Preview {
    NavigationView {
        ProxyView()
    }
}
