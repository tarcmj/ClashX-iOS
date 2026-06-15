import Foundation

struct ProxyGroup: Identifiable, Codable, Equatable {
    let id = UUID()
    let name: String
    let type: GroupType
    var now: String?
    var all: [String]
    var isAlive: Bool = false

    enum GroupType: String, Codable {
        case select = "Selector"
        case urlTest = "URLTest"
        case fallback = "Fallback"
        case loadBalance = "LoadBalance"
        case relay = "Relay"
        case unknown = "Unknown"

        var displayName: String {
            switch self {
            case .select: return "手动选择"
            case .urlTest: return "自动选择"
            case .fallback: return "故障转移"
            case .loadBalance: return "负载均衡"
            case .relay: return "中继"
            case .unknown: return "未知"
            }
        }
    }
}
