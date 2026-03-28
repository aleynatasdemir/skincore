import SwiftUI

@MainActor
class RoutineDetailViewModel: ObservableObject {
    @Published var routine: RoutineDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let routineId: String

    init(routineId: String) {
        self.routineId = routineId
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            routine = try await APIClient.shared.getRoutineDetail(id: routineId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleLike() async {
        guard var current = routine else { return }
        do {
            let response = try await APIClient.shared.toggleRoutineLike(routineId: routineId)
            current.likeCount = response.likeCount
            current.hasLiked = response.isLiked
            routine = current
        } catch {
            print("Like toggle error: \(error)")
        }
    }

    func addComment(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var current = routine else { return }
        do {
            let response = try await APIClient.shared.addRoutineComment(routineId: routineId, text: trimmed)
            let comment = RoutineComment(
                id: response.id,
                userName: response.userName,
                text: response.text,
                createdAt: response.createdAt
            )
            current.comments.append(comment)
            current.commentCount = current.comments.count
            routine = current
        } catch {
            print("Comment error: \(error)")
        }
    }
}

struct RoutineDetailView: View {
    let routineId: String
    let onUpdate: (RoutineDetail) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RoutineDetailViewModel
    @State private var commentText: String = ""

    init(routineId: String, onUpdate: @escaping (RoutineDetail) -> Void = { _ in }) {
        self.routineId = routineId
        self.onUpdate = onUpdate
        _viewModel = StateObject(wrappedValue: RoutineDetailViewModel(routineId: routineId))
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            if viewModel.isLoading && viewModel.routine == nil {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color(hex: "D4728C"))
                    Text("Yükleniyor...")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            } else if let routine = viewModel.routine {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "F3F4F6"))
                                .frame(height: 230)

                            if let imageUrl = routine.coverImageUrl, let url = URL(string: imageUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 230)
                                            .clipShape(RoundedRectangle(cornerRadius: 20))
                                    default:
                                        Image(systemName: "photo")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color(hex: "CBD5E1"))
                                    }
                                }
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(hex: "CBD5E1"))
                            }
                        }

                        HStack(spacing: 12) {
                            AvatarView(name: routine.userName)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(routine.userName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A2E"))
                                Text(timeAgo(routine.createdAt))
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            }
                            Spacer()
                            if let skinType = routine.skinType, !skinType.isEmpty {
                                Text(skinType)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "F3D5DC"))
                                    .foregroundColor(Color(hex: "9A4C5E"))
                                    .cornerRadius(8)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(routine.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color(hex: "1A1A2E"))

                            if let description = routine.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(size: 15))
                                    .foregroundColor(Color(hex: "6B7280"))
                            }
                        }

                        if let tags = routine.tags, !tags.isEmpty {
                            WrapTags(tags: tags)
                        } else if let focus = routine.focus, !focus.isEmpty {
                            WrapTags(tags: [focus])
                        }

                        HStack(spacing: 18) {
                            Button {
                                Task {
                                    await viewModel.toggleLike()
                                    if let updated = viewModel.routine { onUpdate(updated) }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: routine.hasLiked ? "heart.fill" : "heart")
                                        .foregroundColor(routine.hasLiked ? Color(hex: "D4728C") : Color(hex: "9CA3AF"))
                                    Text("\(routine.likeCount)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "6B7280"))
                                }
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "bubble.right")
                                    .foregroundColor(Color(hex: "9CA3AF"))
                                Text("\(routine.commentCount)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "6B7280"))
                            }

                            Spacer()
                        }

                        if !routine.products.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Ürünler")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color(hex: "1A1A2E"))

                                ForEach(routine.products) { product in
                                    RoutineProductRow(product: product)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Yorumlar")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(Color(hex: "1A1A2E"))

                            if routine.comments.isEmpty {
                                Text("Henüz yorum yok")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "9CA3AF"))
                            } else {
                                ForEach(routine.comments) { comment in
                                    CommentRow(comment: comment)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "D4728C").opacity(0.4))
                    Text("Rutin yüklenemedi")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            }
        }
        .navigationTitle("Rutin")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            CommentInputBar(text: $commentText) {
                Task {
                    await viewModel.addComment(text: commentText)
                    commentText = ""
                    if let updated = viewModel.routine { onUpdate(updated) }
                }
            }
        }
        .task {
            await viewModel.fetch()
        }
    }
}

private struct RoutineProductRow: View {
    let product: RoutineProduct

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: product.imageUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "F3F4F6"))
                        .frame(width: 54, height: 54)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(Color(hex: "CBD5E1"))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "1A1A2E"))
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "6B7280"))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

private struct CommentRow: View {
    let comment: RoutineComment

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: comment.userName)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.userName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(timeAgo(comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "4B5563"))
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

private struct CommentInputBar: View {
    @Binding var text: String
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Yorum yaz...", text: $text)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color.white)
                .cornerRadius(14)

            Button(action: onSend) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.white)
                    .padding(12)
                    .background(Color(hex: "D4728C"))
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(hex: "FFF0F0").ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(routineId: "demo")
    }
    .environmentObject(AuthViewModel())
}
