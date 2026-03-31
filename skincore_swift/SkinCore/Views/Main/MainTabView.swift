import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView()
            }

            Tab("Ingredients", systemImage: "leaf.fill", value: 1) {
                IngredientAnalysisView()
            }

            Tab("Scan", systemImage: "viewfinder", value: 2) {
                ScanView()
            }

            Tab("Social", systemImage: "person.2.fill", value: 3) {
                SocialFeedView()
            }

            Tab("Profile", systemImage: "person.fill", value: 4) {
                ProfileView()
            }
        }
        .tint(Color(hex: "D4728C"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
