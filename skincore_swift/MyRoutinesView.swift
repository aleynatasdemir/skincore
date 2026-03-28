import SwiftUI
import Foundation

struct MyRoutinesView: View {
    @State private var routines: [RoutineFeedItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedRoutineId: String?

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            if isLoading {
                ProgressView("Yükleniyor...")
                    .tint(Color(hex: "D4728C"))
            } else if routines.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.3))
                    Text("Henüz bir rutin oluşturmadın")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(routines) { routine in
                            RoutineCardSmall(routine: routine) {
                                selectedRoutineId = routine.id
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Rutinlerim")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { selectedRoutineId.map { IdentifiableString(id: $0) } },
            set: { selectedRoutineId = $0?.id }
        )) { ident in
            NavigationStack {
                RoutineDetailView(routineId: ident.id) { _ in
                    Task { await fetchMyRoutines() }
                }
            }
        }
        .task {
            await fetchMyRoutines()
        }
    }

    private func fetchMyRoutines() async {
        isLoading = true
        do {
            routines = try await APIClient.shared.getMyRoutines()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct RoutineCardSmall: View {
    let routine: RoutineFeedItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let coverUrl = routine.coverImageUrl, !coverUrl.isEmpty {
                    AsyncImage(url: URL(string: coverUrl)) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            placeholder
                        }
                    }
                } else if let firstProduct = routine.products?.first {
                    AsyncImage(url: URL(string: firstProduct.imageUrl ?? "")) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 60, height: 60)
                                .padding(4)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    
                    Text("\(routine.products?.count ?? 0) Ürün • \(timeAgo(routine.createdAt))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "CBD5E1"))
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(hex: "F3D5DC"))
            .frame(width: 60, height: 60)
            .overlay(
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hex: "D4728C"))
            )
    }
}

struct IdentifiableString: Identifiable {
    let id: String
}
