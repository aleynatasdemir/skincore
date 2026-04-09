import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        if #available(iOS 26.0, *) {
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
        } else {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem { Label(lang.s(.tabHome), systemImage: "house.fill") }
                    .tag(0)
                IngredientAnalysisView()
                    .tabItem { Label(lang.s(.tabIngredients), systemImage: "leaf.fill") }
                    .tag(1)
                ScanView()
                    .tabItem { Label(lang.s(.tabScan), systemImage: "viewfinder") }
                    .tag(2)
                SocialFeedView()
                    .tabItem { Label(lang.s(.tabSocial), systemImage: "person.2.fill") }
                    .tag(3)
                ProfileView()
                    .tabItem { Label(lang.s(.tabProfile), systemImage: "person.fill") }
                    .tag(4)
            }
            .tint(Color(hex: "D4728C"))
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(LanguageManager.shared)
}
