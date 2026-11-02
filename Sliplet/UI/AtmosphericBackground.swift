import SwiftUI

struct AtmosphericBackground: View {
    var alignedToWindow = false

    var body: some View {
        GeometryReader { proxy in
            let bounds = alignedToWindow ? Self.windowBounds : nil
            let region = proxy.frame(in: .global)
            Image("WalletAtmosphere")
                .resizable()
                .scaledToFill()
                .frame(width: bounds?.width ?? proxy.size.width, height: bounds?.height ?? proxy.size.height)
                .blur(radius: 3, opaque: true)
                .clipped()
                .offset(x: bounds == nil ? 0 : -region.minX, y: bounds == nil ? 0 : -region.minY)
        }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }

    private static var windowBounds: CGRect? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.bounds
    }
}
