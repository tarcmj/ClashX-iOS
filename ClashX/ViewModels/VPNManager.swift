import Foundation
import NetworkExtension
import Combine

@MainActor
class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var isConnected = false
    @Published var status: NEVPNStatus = .invalid
    @Published var isConnecting = false

    private var statusObserver: NSObjectProtocol?

    private init() {
        loadStatus()
        startObserving()
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    func connect() async throws {
        let manager = try await loadOrCreateManager()
        manager.isEnabled = true

        // Configure the tunnel protocol
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.serverAddress = "127.0.0.1"
        tunnelProtocol.providerBundleIdentifier = "\(Bundle.main.bundleIdentifier ?? "com.clashx").tunnel"
        tunnelProtocol.providerConfiguration = [
            "configPath": getConfigPath(),
            "mode": "rule"
        ]

        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = "ClashX"

        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        try manager.connection.startVPNTunnel()
        isConnecting = true
    }

    func disconnect() async {
        let manager = try? await loadOrCreateManager()
        manager?.connection.stopVPNTunnel()
        isConnected = false
        isConnecting = false
    }

    func toggle() async {
        if isConnected || status == .connected {
            await disconnect()
        } else {
            try? await connect()
        }
    }

    // MARK: - Private Methods

    private func loadStatus() {
        Task {
            let manager = try? await loadOrCreateManager()
            if let manager = manager {
                await MainActor.run {
                    self.status = manager.connection.status
                    self.isConnected = status == .connected
                    self.isConnecting = status == .connecting
                }
            }
        }
    }

    private func startObserving() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let session = notification.object as? NETunnelProviderSession,
                  let manager = try? session.manager as? NETunnelProviderManager else {
                return
            }

            Task { @MainActor in
                self.status = manager.connection.status
                self.isConnected = self.status == .connected
                self.isConnecting = self.status == .connecting
            }
        }
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        if let manager = managers.first {
            return manager
        }
        return NETunnelProviderManager()
    }

    private func getConfigPath() -> String {
        let documents = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.clashx"
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("config.yaml").path
    }
}
