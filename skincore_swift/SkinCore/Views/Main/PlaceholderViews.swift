import SwiftUI

// ScanView is implemented in Views/Home/ScanView.swift
// SearchHistoryView is implemented in Views/History/SearchHistoryView.swift

struct WishlistView: View {
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text(lang.s(.placeholderFavorites))
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(lang.s(.placeholderFavoritesDesc))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}

struct ProfilePlaceholderView: View {
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "FFF0F0").ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text(lang.s(.placeholderProfile))
                        .font(.title2.bold())
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(lang.s(.placeholderComingSoon))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }
        }
    }
}
