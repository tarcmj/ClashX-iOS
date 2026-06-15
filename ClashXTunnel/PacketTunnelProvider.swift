import NetworkExtension
import os.log

class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.clashx.tunnel", category: "PacketTunnel")

    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        os_log("Starting tunnel...", log: log, type: .info)

        // Read configuration from provider configuration
        guard let config = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = config.providerConfiguration else {
            os_log("Missing provider configuration", log: log, type: .error)
            throw TunnelError.missingConfiguration
        }

        let configPath = providerConfig["configPath"] as? String ?? ""
        let mode = providerConfig["mode"] as? String ?? "rule"

        os_log("Config path: %{public}s, mode: %{public}s", log: log, type: .info, configPath, mode)

        // Set up the tunnel network settings
        let networkSettings = createNetworkSettings()
        try await setTunnelNetworkSettings(networkSettings)

        os_log("Tunnel network settings applied", log: log, type: .info)

        // In a full implementation, this is where you would:
        // 1. Initialize the Clash core via the gomobile framework
        // 2. Start packet processing via the tunnel flow
        // 3. Monitor the tunnel for keepalive

        // Start reading packets from the virtual interface
        Task {
            await readPackets()
        }

        os_log("Tunnel started successfully", log: log, type: .info)
    }

    override func stopTunnel(with reason: NEProviderStopReason) async {
        os_log("Stopping tunnel, reason: %{public}s", log: log, type: .info, String(describing: reason))

        // In a full implementation, stop the Clash core here
        // ClashCore.shared.stop()

        os_log("Tunnel stopped", log: log, type: .info)
    }

    override func handleAppMessage(_ messageData: Data) async -> Data? {
        os_log("Received app message: %d bytes", log: log, type: .debug, messageData.count)

        // Handle messages from the main app
        // You can use this for IPC between the app and extension
        return nil
    }

    override func sleep() async {
        os_log("Device going to sleep", log: log, type: .info)
    }

    override func wake() {
        os_log("Device woke up", log: log, type: .info)
    }

    // MARK: - Private Methods

    private func createNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["192.168.200.2"], subnetMasks: ["255.255.255.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
        ]
        settings.ipv4Settings = ipv4Settings

        // IPv6 settings
        let ipv6Settings = NEIPv6Settings(addresses: ["fd00::2"], networkPrefixLengths: [64])
        ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6Settings

        // DNS settings
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        settings.dnsSettings = dnsSettings

        // MTU
        settings.mtu = 1500

        return settings
    }

    private func readPackets() async {
        let flow = packetFlow

        while true {
            // Read packets in batches
            let (packetData, protocolTypes) = await flow.readPackets()
            if packetData.isEmpty {
                // No packets available, wait a bit
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                continue
            }

            // Process each packet
            for (index, packet) in packetData.enumerated() {
                let protocolType = protocolTypes[index]
                // Forward packet to Clash core for processing
                _ = processPacket(packet, protocolType: protocolType)
            }
        }
    }

    private func processPacket(_ packet: Data, protocolType: NSNumber) -> Data? {
        // In production, this is where the Clash core processes the packet.
        // The Clash core handles proxy protocol encoding, routing rules, etc.
        // For now, we simply return the packet unmodified (direct mode passthrough).
        return packet
    }

    enum TunnelError: Error, LocalizedError {
        case missingConfiguration

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Tunnel configuration is missing"
            }
        }
    }
}
