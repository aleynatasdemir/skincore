import SwiftUI

struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text("Discover")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("Coming Soon")
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}

// ScanView is implemented in Views/Home/ScanView.swift

struct WishlistView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text("Wishlist")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("Your saved products")
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack {
                    Image(systemName: "clock.arrow.counterclockwise")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text("History")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("Recently viewed products")
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}
