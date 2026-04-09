import SwiftUI
import Kingfisher

struct CachedImageView: View {
    let url: URL?
    var contentMode: SwiftUI.ContentMode = .fill
    var placeholderIcon: String = "photo"
    var placeholderIconSize: CGFloat = 24

    var body: some View {
        KFImage(url)
            .resizable()
            .placeholder {
                ZStack {
                    Color(hex: "F3F4F6")
                    Image(systemName: placeholderIcon)
                        .font(.system(size: placeholderIconSize))
                        .foregroundColor(Color(hex: "CBD5E1"))
                }
            }
            .fade(duration: 0.2)
            .aspectRatio(contentMode: contentMode)
    }
}
