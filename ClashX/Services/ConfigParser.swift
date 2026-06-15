import Foundation

class ConfigParser {
    enum ParserError: Error, LocalizedError {
        case invalidYAML
        case missingRequiredField(String)

        var errorDescription: String? {
            switch self {
            case .invalidYAML:
                return "YAML 格式无效"
            case .missingRequiredField(let field):
                return "缺少必要字段: \(field)"
            }
        }
    }

    /// Parse a Clash YAML config string into a ClashConfig object.
    /// This is a simplified parser. In production, you'd use a YAML library
    /// like Yams (which we include via Swift Package Manager).
    static func parse(yamlString: String) throws -> ClashConfig {
        var config = ClashConfig()

        // Simple line-by-line parsing. In production, use Yams.
        let lines = yamlString.components(separatedBy: .newlines)

        var currentSection: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Detect sections
            if trimmed.hasSuffix(":") && !trimmed.hasPrefix("-") {
                currentSection = trimmed.replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces)
                continue
            }

            // Parse key-value pairs
            if let colonIndex = trimmed.firstIndex(of: ":"), currentSection == nil {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

                switch key {
                case "port":
                    config.port = Int(value) ?? 7890
                case "socks-port":
                    config.socksPort = Int(value) ?? 7891
                case "mixed-port":
                    config.mixedPort = Int(value) ?? 7892
                case "redir-port":
                    config.redirPort = Int(value) ?? 7893
                case "allow-lan":
                    config.allowLan = value == "true"
                case "mode":
                    config.mode = ClashConfig.Mode(rawValue: value) ?? .rule
                case "log-level":
                    config.logLevel = ClashConfig.LogLevel(rawValue: value) ?? .info
                case "external-controller":
                    config.externalController = value
                case "secret":
                    config.secret = value
                default:
                    break
                }
            }

            // Parse proxy entries
            // This is simplified; full YAML parsing requires a proper library
        }

        return config
    }

    /// Parse from file URL
    static func parse(fileURL: URL) throws -> ClashConfig {
        let yamlString = try String(contentsOf: fileURL, encoding: .utf8)
        return try parse(yamlString: yamlString)
    }
}
