import SwiftUI

extension View {
    /// iPad'de sheet'i büyük gösterir, aşağı kaydırarak kapatılabilir.
    /// iPhone'da hiçbir şey yapmaz.
    @ViewBuilder
    func iPadLargeSheet() -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            self
        }
    }
}
