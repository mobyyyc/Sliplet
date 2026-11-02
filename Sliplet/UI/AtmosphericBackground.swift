import SwiftUI

/// One opaque, static plate shared by screen backgrounds and the wallet's pocket mask.
struct AtmosphericBackground: View {
    @Environment(\.colorScheme) private var scheme
    var alignedToWindow = false

    var body: some View {
        Group {
            if scheme == .dark, let image = Self.plate {
                GeometryReader { proxy in
                    let bounds = alignedToWindow ? Self.windowBounds : nil
                    let region = proxy.frame(in: .global)
                    Image(uiImage: image).resizable()
                        .frame(width: bounds?.width ?? proxy.size.width, height: bounds?.height ?? proxy.size.height)
                        .offset(x: bounds == nil ? 0 : -region.minX, y: bounds == nil ? 0 : -region.minY)
                }.clipped()
            } else {
                Color(uiColor: .systemGroupedBackground)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }

    private static var windowBounds: CGRect? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.bounds
    }

    // Rasterize once. Wallet movement and scrolling only composite the finished image.
    private static let plate: UIImage? = {
        let glow = Color(white: 0.43)
        let lighting = ZStack {
            Color(white: 5.0 / 255)
            LinearGradient(colors: [.clear, Color(white: 0.12).opacity(0.28), .clear],
                           startPoint: .topTrailing, endPoint: .bottomLeading)
            Ellipse()
                .fill(RadialGradient(colors: [glow.opacity(0.40), glow.opacity(0.17), .clear],
                                     center: .center, startRadius: 0, endRadius: 250))
                .frame(width: 500, height: 500)
                .scaleEffect(x: 1.9, y: 0.48)
                .rotationEffect(.degrees(-30))
                .blur(radius: 24)
                .offset(x: -42, y: 118)
            RadialGradient(colors: [Color(white: 0.33).opacity(0.13), .clear],
                           center: UnitPoint(x: 0.95, y: 0.52), startRadius: 0, endRadius: 330)
            if let grain {
                Image(decorative: grain, scale: 1).resizable(resizingMode: .tile).opacity(0.012)
            }
        }.frame(width: 420, height: 900).clipped()
        let renderer = ImageRenderer(content: lighting)
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.uiImage
    }()

    private static let grain: CGImage? = {
        let side = 128
        var state: UInt32 = 27
        let bytes = (0..<(side * side)).map { _ -> UInt8 in
            state = state &* 1664525 &+ 1013904223
            return UInt8(state >> 24)
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8,
                       bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: [], provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)
    }()
}

private struct AtmosphericScreen: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.scrollContentBackground(scheme == .dark ? .hidden : .automatic)
            .background { if scheme == .dark { AtmosphericBackground().ignoresSafeArea() } }
    }
}

extension View {
    func atmosphericScreen() -> some View { modifier(AtmosphericScreen()) }
}
