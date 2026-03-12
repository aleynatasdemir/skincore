import SwiftUI

// ScanView is implemented in Views/Home/ScanView.swift
// SearchHistoryView is implemented in Views/History/SearchHistoryView.swift

struct WishlistView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text("Favorites")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("Your saved products")
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text("Profile")
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text("Coming Soon")
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}
