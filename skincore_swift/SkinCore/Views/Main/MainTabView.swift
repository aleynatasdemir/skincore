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
            
            Tab("Favorites", systemImage: "heart.fill", value: 3) {
                FavoritesView()
            }
            
            Tab("History", systemImage: "clock.fill", value: 4) {
                SearchHistoryView()
            }
        }
        .tint(Color(hex: "D4728C"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
