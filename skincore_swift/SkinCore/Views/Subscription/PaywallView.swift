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
                        FeatureRow(icon: "staroflife.fill",
                                   title: lang.s(.paywallFeature3Title),
                                   subtitle: lang.s(.paywallFeature3Subtitle))
                        FeatureRow(icon: "nosign",
                                   title: lang.language == .tr ? "Reklamsız Deneyim" : "Ad-Free Experience",
                                   subtitle: lang.language == .tr ? "Hiçbir reklam görmeden kullan" : "Use the app without any ads")
                    }
                    .padding(.horizontal)

                    // MARK: - Plan Seçimi
                    if subscriptionService.isLoading {
                        ProgressView().frame(height: 120)
                    } else {
                        VStack(spacing: 12) {
                            // Yıllık Plan
                            PlanCard(
                                product: subscriptionService.yearlyProduct,
                                isSelected: subscriptionService.selectedProductID == SubscriptionService.yearlyProductID,
                                badge: lang.language == .tr ? "En Popüler" : "Most Popular",
                                periodLabel: lang.language == .tr ? "/ yıl" : "/ year",
                                perMonthLabel: subscriptionService.yearlyProduct.map { p in
                                    let monthly = p.price / 12
                                    let monthlyStr = monthly.formatted(p.priceFormatStyle)
                                    return lang.language == .tr
                                        ? "≈ \(monthlyStr) / ay"
                                        : "≈ \(monthlyStr) / mo"
                                }
                            ) {
                                subscriptionService.selectedProductID = SubscriptionService.yearlyProductID
                            }

                            // Aylık Plan
                            PlanCard(
                                product: subscriptionService.monthlyProduct,
                                isSelected: subscriptionService.selectedProductID == SubscriptionService.monthlyProductID,
                                badge: nil,
                                periodLabel: lang.language == .tr ? "/ ay" : "/ month",
                                perMonthLabel: nil
                            ) {
                                subscriptionService.selectedProductID = SubscriptionService.monthlyProductID
                            }
                        }
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
                    .disabled(subscriptionService.isLoading || subscriptionService.selectedProduct == nil)

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

// MARK: - Plan Card

private struct PlanCard: View {
    let product: StoreKit.Product?
    let isSelected: Bool
    let badge: String?
    let periodLabel: String
    let perMonthLabel: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Seçim göstergesi
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color(hex: "D4728C") : Color(hex: "D1D5DB"), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color(hex: "D4728C"))
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(product?.displayName ?? "–")
                            .font(.subheadline.bold())
                            .foregroundColor(Color(hex: "1A1A2E"))
                        if let badge {
                            Text(badge)
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "D4728C"))
                                .clipShape(Capsule())
                        }
                    }
                    if let perMonthLabel {
                        Text(perMonthLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let product {
                    Text(product.displayPrice + " " + periodLabel)
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: "D4728C"))
                } else {
                    ProgressView().scaleEffect(0.7)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "FFF0F0"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? Color(hex: "D4728C") : Color(hex: "E5E7EB"),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
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
