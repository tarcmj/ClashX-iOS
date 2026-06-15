import Foundation
import Combine

@MainActor
class TrafficMonitor: ObservableObject {
    static let shared = TrafficMonitor()

    @Published var uploadSpeed: Double = 0  // bytes/sec
    @Published var downloadSpeed: Double = 0
    @Published var totalUpload: Int64 = 0
    @Published var totalDownload: Int64 = 0
    @Published var isMonitoring = false

    private var timer: AnyCancellable?
    private var lastUp: Int64 = 0
    private var lastDown: Int64 = 0

    private init() {}

    func startMonitoring() {
        isMonitoring = true
        lastUp = 0
        lastDown = 0

        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.updateTraffic()
                }
            }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        isMonitoring = false
        uploadSpeed = 0
        downloadSpeed = 0
    }

    private func updateTraffic() async {
        let controller = ClashController.shared
        guard await controller.isReachable() else { return }

        do {
            let traffic = try await controller.getTraffic()

            // Calculate speeds
            let upDiff = traffic.up - lastUp
            let downDiff = traffic.down - lastDown

            if lastUp > 0 {
                uploadSpeed = Double(max(0, upDiff))
            }
            if lastDown > 0 {
                downloadSpeed = Double(max(0, downDiff))
            }

            totalUpload = traffic.up
            totalDownload = traffic.down
            lastUp = traffic.up
            lastDown = traffic.down
        } catch {
            // Silently fail - Clash might not be running
        }
    }
}
