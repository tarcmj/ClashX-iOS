import Foundation

/// Configuration passed from the main app to the tunnel extension.
struct TunnelConfig: Codable {
    let configPath: String
    let mode: String
    let socksPort: Int
    let mixedPort: Int
    let logLevel: String

    /// Encode to Data for IPC between app and extension.
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    /// Decode from Data received from the app.
    static func decode(from data: Data) -> TunnelConfig? {
        try? JSONDecoder().decode(TunnelConfig.self, from: data)
    }
}
