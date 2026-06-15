import SwiftUI

struct DashboardView: View {
    @StateObject private var vpnManager = VPNManager.shared
    @StateObject private var trafficMonitor = TrafficMonitor.shared
    @State private var selectedMode: ClashConfig.Mode = .rule
    @State private var showModePicker = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // VPN Status Card
                    statusCard

                    // Traffic Card
                    trafficCard

                    // Mode Selector
                    modeSelector

                    // Quick Actions
                    quickActions
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ClashX")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .onChange(of: vpnManager.isConnected) { _, connected in
            if connected {
                trafficMonitor.startMonitoring()
            } else {
                trafficMonitor.stopMonitoring()
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            // Connection status icon
            ZStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 80, height: 80)

                Image(systemName: vpnManager.isConnected
                    ? "shield.checkered"
                    : "shield.slash")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text(vpnManager.isConnected ? "已连接" : "未连接")
                .font(.title2)
                .fontWeight(.semibold)

            Text(statusDetail)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Connect/Disconnect button
            Button(action: toggleVPN) {
                Text(vpnManager.isConnected ? "断开连接" : "连接")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(connectionColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(vpnManager.isConnecting)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Traffic Card

    private var trafficCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("流量", systemImage: "arrow.up.arrow.down")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 40) {
                // Upload
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(formatBytes(trafficMonitor.uploadSpeed) + "/s")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                    Text("上传")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Download
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text(formatBytes(trafficMonitor.downloadSpeed) + "/s")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                    Text("下载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Total traffic
            HStack {
                Text("总计")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("↑ \(formatBytes(Double(trafficMonitor.totalUpload)))")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("↓ \(formatBytes(Double(trafficMonitor.totalDownload)))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Label("运行模式", systemImage: "gear")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                ForEach(ClashConfig.Mode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                        Task {
                            try? await ClashController.shared.updateMode(mode)
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(mode.displayName)
                                .font(.subheadline)
                                .fontWeight(selectedMode == mode ? .semibold : .regular)
                            Text(modeIcon(mode))
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedMode == mode ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedMode == mode ? .accentColor : .secondary)
                    }
                }
            }
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(spacing: 12) {
            HStack {
                Label("快捷操作", systemImage: "square.grid.2x2")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                NavigationLink(destination: ProxyView()) {
                    quickActionButton(
                        icon: "list.bullet",
                        title: "代理",
                        color: .blue
                    )
                }

                NavigationLink(destination: ProfilesView()) {
                    quickActionButton(
                        icon: "doc.text",
                        title: "配置",
                        color: .orange
                    )
                }

                NavigationLink(destination: LogView()) {
                    quickActionButton(
                        icon: "text.alignleft",
                        title: "日志",
                        color: .purple
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }

    private func quickActionButton(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(12)

            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private var connectionColor: Color {
        if vpnManager.isConnected { return .green }
        if vpnManager.isConnecting { return .orange }
        return .gray
    }

    private var statusDetail: String {
        if vpnManager.isConnecting { return "正在连接..." }
        if vpnManager.isConnected { return "所有流量通过 Clash 代理" }
        return "点击连接开始使用"
    }

    private func toggleVPN() {
        Task {
            await vpnManager.toggle()
        }
    }

    private func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = bytes
        var unitIndex = 0

        while abs(value) >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: "%.1f %@", value, units[unitIndex])
    }

    private func modeIcon(_ mode: ClashConfig.Mode) -> String {
        switch mode {
        case .rule: return "规则分流"
        case .global: return "全局代理"
        case .direct: return "直接连接"
        }
    }
}

#Preview {
    DashboardView()
}
