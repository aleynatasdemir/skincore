import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscriptionService: SubscriptionService
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // MARK: - Başlık
                    VStack(spacing: 8) {
                        Image("app_logo_header")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 56)
                            .padding(.top, 32)

                        Text("SkinCore Premium")
                            .font(.largeTitle.bold())

                        Text(lang.s(.paywallSubtitle))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Özellikler
                    VStack(spacing: 16) {
                        FeatureRow(icon: "infinity",
                                   title: lang.s(.paywallFeature1Title),
                                   subtitle: lang.s(.paywallFeature1Subtitle))
                        FeatureRow(icon: "checkmark.seal.fill",
                                   title: lang.s(.paywallFeature2Title),
                                   subtitle: lang.s(.paywallFeature2Subtitle))
                        FeatureRow(icon: "heart.fill",
                                   title: lang.s(.paywallFeature3Title),
                                   subtitle: lang.s(.paywallFeature3Subtitle))
                        FeatureRow(icon: "person.2.fill",
                                   title: lang.s(.paywallFeature4Title),
                                   subtitle: lang.s(.paywallFeature4Subtitle))
                    }
                    .padding(.horizontal)

                    // MARK: - Fiyat Kartı
                    if subscriptionService.isLoading {
                        ProgressView()
                            .frame(height: 80)
                    } else if let product = subscriptionService.storeProducts.first {
                        VStack(spacing: 6) {
                            Text(product.displayName)
                                .font(.headline)
                            Text(product.displayPrice + " " + lang.s(.paywallPerMonth))
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(hex: "D4728C"))
                            Text(lang.s(.paywallCancelAnytime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "FFF0F0"))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(hex: "D4728C"), lineWidth: 1.5)
                                )
                        )
                        .padding(.horizontal)
                    } else {
                        Text(lang.s(.paywallProductNotLoaded))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let error = subscriptionService.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // MARK: - Satın Al Butonu
                    Button {
                        Task {
                            let success = await subscriptionService.purchase()
                            if success { dismiss() }
                        }
                    } label: {
                        HStack {
                            if subscriptionService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(lang.s(.paywallGoToPremium))
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(hex: "D4728C"))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.horizontal)
                    }
                    .disabled(subscriptionService.isLoading || subscriptionService.storeProducts.isEmpty)

                    // MARK: - Restore
                    Button {
                        Task { await subscriptionService.restorePurchases() }
                    } label: {
                        Text(lang.s(.paywallRestore))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    // MARK: - Yasal
                    Text(lang.s(.paywallLegal))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.s(.paywallClose)) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Color(hex: "D4728C"))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
