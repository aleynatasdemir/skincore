import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView()
            }
            
            Tab("Discover", systemImage: "safari.fill", value: 1) {
                DiscoverView()
            }
            
            Tab("Scan", systemImage: "viewfinder", value: 2) {
                ScanView()
            }
            
            Tab("Wishlist", systemImage: "heart.fill", value: 3) {
                WishlistView()
            }
            
            Tab("History", systemImage: "clock.arrow.counterclockwise", value: 4) {
                HistoryView()
            }
        }
        .tint(Color(hex: "D4728C"))
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
