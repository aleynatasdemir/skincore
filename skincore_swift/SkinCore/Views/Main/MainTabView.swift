import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(lang.s(.tabHome), systemImage: "house.fill", value: 0) {
                HomeView()
            }
            Tab(lang.s(.tabIngredients), systemImage: "leaf.fill", value: 1) {
                IngredientAnalysisView()
            }
            Tab(lang.s(.tabScan), systemImage: "viewfinder", value: 2) {
                ScanView()
            }
            Tab(lang.s(.tabSocial), systemImage: "person.2.fill", value: 3) {
                SocialFeedView()
            }
            Tab(lang.s(.tabProfile), systemImage: "person.fill", value: 4) {
                ProfileView()
            }
        }
        .tint(Color(hex: "D4728C"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager.shared)
}
