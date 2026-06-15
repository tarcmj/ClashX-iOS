import SwiftUI

@main
struct ClashXApp: App {
    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(darkMode ? .dark : nil)
                .onAppear {
                    setupAppearance()
                }
        }
    }

    private func setupAppearance() {
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
