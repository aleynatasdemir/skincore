import SwiftUI
import PhotosUI

struct ProductRequestView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var lang: LanguageManager

    @State private var brandName = ""
    @State private var productName = ""

    @State private var frontImage: UIImage?
    @State private var ingredientsImage: UIImage?

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    @State private var showPhotoDialog = false
    @State private var showImagePicker = false
    @State private var isPickingFront = true
    @State private var currentSourceType: UIImagePickerController.SourceType = .photoLibrary

    private var canSubmit: Bool {
        !brandName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (frontImage != nil || ingredientsImage != nil) &&
        !isLoading
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF0F0").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Header
                    VStack(spacing: 8) {
                        Text(lang.s(.appBrand))
                            .font(.system(size: 28, weight: .light, design: .serif))
                            .foregroundColor(Color(hex: "D4728C"))

                        Text(lang.s(.productRequestTitle))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Color(hex: "1A1A2E"))

                        Text(lang.s(.productRequestSubtitle))
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 24)

                    // Marka & ürün adı
                    VStack(spacing: 12) {
                        InputField(
                            icon: "tag.fill",
                            placeholder: lang.s(.productRequestBrandPlaceholder),
                            text: $brandName
                        )
                        InputField(
                            icon: "cube.box.fill",
                            placeholder: lang.s(.productRequestProductPlaceholder),
                            text: $productName
                        )
                    }
                    .padding(.horizontal, 24)

                    // Fotoğraflar
                    VStack(spacing: 16) {
                        PhotoCard(
                            title: lang.s(.productRequestFrontTitle),
                            subtitle: lang.s(.productRequestFrontSubtitle),
                            icon: "photo.fill",
                            image: frontImage
                        ) {
                            isPickingFront = true
                            showPhotoDialog = true
                        }

                        PhotoCard(
                            title: lang.s(.productRequestIngredientsTitle),
                            subtitle: lang.s(.productRequestIngredientsSubtitle),
                            icon: "list.bullet.rectangle.fill",
                            image: ingredientsImage
                        ) {
                            isPickingFront = false
                            showPhotoDialog = true
                        }
                    }
                    .padding(.horizontal, 24)

                    // Hata mesajı
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Color(hex: "EF4444"))
                            .padding(.horizontal, 24)
                    }

                    // Gönder butonu
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15))
                                Text(lang.s(.productRequestSubmit))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(canSubmit ? Color(hex: "1A1A2E") : Color(hex: "E5E7EB"))
                        .foregroundColor(canSubmit ? .white : Color(hex: "9CA3AF"))
                        .cornerRadius(28)
                    }
                    .disabled(!canSubmit)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color(hex: "1A1A2E"))
                }
            }
        }
        .confirmationDialog(lang.s(.productRequestSelectPhoto), isPresented: $showPhotoDialog, titleVisibility: .visible) {
            Button("Kamera") {
                currentSourceType = .camera
                showImagePicker = true
            }
            Button("Galeri") {
                currentSourceType = .photoLibrary
                showImagePicker = true
            }
            Button(lang.s(.cancel), role: .cancel) { }
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ProductRequestImagePicker(sourceType: currentSourceType, selectedImage: isPickingFront ? $frontImage : $ingredientsImage)
                .ignoresSafeArea()
        }
        .alert(lang.s(.productRequestAlertTitle), isPresented: $showSuccess) {
            Button(lang.s(.ok)) { dismiss() }
        } message: {
            Text(lang.s(.productRequestAlertMsg))
        }
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil

        let frontData = frontImage?.jpegData(compressionQuality: 0.8)
        let ingredientsData = ingredientsImage?.jpegData(compressionQuality: 0.8)

        do {
            _ = try await APIClient.shared.submitProductRequest(
                brandName: brandName.trimmingCharacters(in: .whitespaces),
                productName: productName.isEmpty ? nil : productName.trimmingCharacters(in: .whitespaces),
                frontImageData: frontData,
                ingredientsImageData: ingredientsData
            )
            showSuccess = true
        } catch let error as APIClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - InputField

private struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "9CA3AF"))
                .frame(width: 24)
            TextField("", text: $text,
                     prompt: Text(placeholder).foregroundColor(Color(hex: "6B7280")))
                .foregroundColor(Color(hex: "1A1A2E"))
                .accentColor(Color(hex: "1A1A2E"))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "E5E7EB"), lineWidth: 1)
        )
    }
}

// MARK: - PhotoCard

private struct PhotoCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let image: UIImage?
    let onTap: () -> Void
    @EnvironmentObject var lang: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "D4728C"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A2E"))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "9CA3AF"))
                }
            }

            Button(action: onTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(
                                    image != nil ? Color(hex: "D4728C") : Color(hex: "E5E7EB"),
                                    style: StrokeStyle(lineWidth: 1.5, dash: image != nil ? [] : [6])
                                )
                        )
                        .frame(height: 140)

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(hex: "D4728C").opacity(0.6))
                            Text(lang.s(.productRequestSelectPhoto))
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "9CA3AF"))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }
}
import SwiftUI
import UIKit

struct ProductRequestImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ProductRequestImagePicker

        init(_ parent: ProductRequestImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
