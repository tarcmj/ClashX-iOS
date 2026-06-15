import Foundation

struct ClashConfig: Codable, Equatable {
    var port: Int = 7890
    var socksPort: Int = 7891
    var mixedPort: Int = 7892
    var redirPort: Int = 7893
    var allowLan: Bool = false
    var mode: Mode = .rule
    var logLevel: LogLevel = .info
    var externalController: String = "127.0.0.1:9090"
    var secret: String = ""
    var proxies: [ProxyNode] = []
    var proxyGroups: [ProxyGroup] = []
    var rules: [String] = []

    enum Mode: String, Codable, CaseIterable {
        case rule = "Rule"
        case global = "Global"
        case direct = "Direct"

        var displayName: String {
            switch self {
            case .rule: return "规则"
            case .global: return "全局"
            case .direct: return "直连"
            }
        }
    }

    enum LogLevel: String, Codable, CaseIterable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
        case silent = "silent"
    }

    enum CodingKeys: String, CodingKey {
        case port
        case socksPort = "socks-port"
        case mixedPort = "mixed-port"
        case redirPort = "redir-port"
        case allowLan = "allow-lan"
        case mode
        case logLevel = "log-level"
        case externalController = "external-controller"
        case secret
        case proxies
        case proxyGroups = "proxy-groups"
        case rules
    }
}
