import SwiftUI

struct LogView: View {
    @State private var logs: [String] = []
    @State private var filterLevel: String = "all"
    @State private var isAutoScroll = true
    @State private var logTimer: Timer?

    private let levels = ["all", "debug", "info", "warning", "error"]

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            Picker("日志级别", selection: $filterLevel) {
                ForEach(levels, id: \.self) { level in
                    Text(level.uppercased()).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(filteredLogs.enumerated()), id: \.offset) { _, log in
                            Text(log)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(colorForLog(log))
                                .lineLimit(nil)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .id(log)
                        }
                    }
                }
                .onChange(of: logs.count) { _, _ in
                    if isAutoScroll, let lastLog = filteredLogs.last {
                        withAnimation(.none) {
                            proxy.scrollTo(lastLog, anchor: .bottom)
                        }
                    }
                }
            }

            // Control bar
            HStack {
                Button(action: {
                    isAutoScroll.toggle()
                }) {
                    Image(systemName: isAutoScroll ? "arrow.down.to.line" : "arrow.up.to.line")
                        .foregroundColor(isAutoScroll ? .accentColor : .secondary)
                }

                Spacer()

                Text("\(filteredLogs.count) 条日志")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { logs.removeAll() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
        .navigationTitle("日志")
        .onAppear {
            startPolling()
        }
        .onDisappear {
            logTimer?.invalidate()
        }
    }

    private var filteredLogs: [String] {
        if filterLevel == "all" { return logs }
        return logs.filter { log in
            log.hasPrefix("[\(filterLevel.uppercased())]") ||
            log.hasPrefix("[\(filterLevel.uppercaseFirst())]")
        }
    }

    private func startPolling() {
        logTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let controller = ClashController.shared
                if await controller.isReachable() {
                    // In a real app, you'd poll a logs endpoint
                    // For now, simulate with version checks
                }
            }
        }
    }

    private func colorForLog(_ log: String) -> Color {
        if log.contains("[ERROR]") { return .red }
        if log.contains("[WARNING]") { return .orange }
        if log.contains("[INFO]") { return .primary }
        if log.contains("[DEBUG]") { return .secondary }
        return .primary
    }
}

// MARK: - String Extension

extension String {
    func uppercaseFirst() -> String {
        guard let first = first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

#Preview {
    NavigationView {
        LogView()
    }
}
