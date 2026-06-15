import Foundation

/// Communicates with the Clash core via its HTTP API (external controller).
class ClashController {
    static let shared = ClashController()

    private var baseURL: String {
        return "http://127.0.0.1:9090"
    }

    private var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }

    // MARK: - Config

    func getConfig() async throws -> ClashConfig {
        let data = try await get("/configs")
        return try JSONDecoder().decode(ClashConfig.self, from: data)
    }

    func updateMode(_ mode: ClashConfig.Mode) async throws {
        let body = ["mode": mode.rawValue]
        var request = URLRequest(url: URL(string: "\(baseURL)/configs")!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 204 else {
            throw ClashError.requestFailed
        }
    }

    // MARK: - Proxies

    func getProxies() async throws -> [String: Any] {
        let data = try await get("/proxies")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["proxies"] as? [String: Any] ?? [:]
    }

    func selectProxy(groupName: String, proxyName: String) async throws {
        let body = ["name": proxyName]
        var request = URLRequest(url: URL(string: "\(baseURL)/proxies/\(groupName)")!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ClashError.requestFailed
        }
    }

    func delayTest(proxyName: String) async throws -> Int {
        let data = try await get("/proxies/\(proxyName)/delay?timeout=5000&url=http://www.gstatic.com/generate_204")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Int]
        return json?["delay"] ?? 0
    }

    // MARK: - Traffic

    func getTraffic() async throws -> (up: Int64, down: Int64) {
        let data = try await get("/traffic")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Int64]
        return (json?["up"] ?? 0, json?["down"] ?? 0)
    }

    // MARK: - Versions

    func getVersion() async throws -> String {
        let data = try await get("/version")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]
        return json?["version"] ?? "unknown"
    }

    // MARK: - Health

    func isReachable() async -> Bool {
        do {
            let data = try await get("/version")
            return !data.isEmpty
        } catch {
            return false
        }
    }

    // MARK: - Internal

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw ClashError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ClashError.requestFailed
        }
        return data
    }

    enum ClashError: Error, LocalizedError {
        case invalidURL
        case requestFailed
        case notConnected

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的 URL"
            case .requestFailed: return "请求失败"
            case .notConnected: return "Clash 核心未连接"
            }
        }
    }
}
