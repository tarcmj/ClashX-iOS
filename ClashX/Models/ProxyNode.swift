import Foundation

struct ProxyNode: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let type: ProxyType
    let server: String?
    let port: Int?
    var delay: Int?
    var isAlive: Bool = false

    enum ProxyType: String, Codable {
        case shadowsocks = "Shadowsocks"
        case vmess = "VMess"
        case trojan = "Trojan"
        case socks5 = "Socks5"
        case http = "Http"
        case direct = "Direct"
        case reject = "Reject"
        case compat = "Compatible"
        case pass = "Pass"
        case relay = "Relay"
        case hysteria2 = "Hysteria2"
        case tUIC = "TUIC"
        case unknown = "Unknown"

        var iconName: String {
            switch self {
            case .shadowsocks: return "lock.shield"
            case .vmess: return "v.circle"
            case .trojan: return "t.circle"
            case .socks5: return "s.circle"
            case .http: return "globe"
            case .direct: return "arrow.right"
            case .reject: return "xmark.circle"
            default: return "questionmark.circle"
            }
        }
    }
}
