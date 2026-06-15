import Foundation

struct Profile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var sourceURL: String?
    var localPath: String
    var isActive: Bool = false
    var lastUpdated: Date?
    var createdAt: Date

    init(name: String, localPath: String, sourceURL: String? = nil) {
        self.id = UUID()
        self.name = name
        self.localPath = localPath
        self.sourceURL = sourceURL
        self.createdAt = Date()
    }
}
