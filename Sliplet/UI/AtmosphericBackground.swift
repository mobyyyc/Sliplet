import SwiftUI

/// One opaque, static plate shared by screen backgrounds and the wallet's pocket mask.
struct AtmosphericBackground: View {
    @Environment(\.colorScheme) private var scheme
    var alignedToWindow = false

    var body: some View {
        Group {
            if let image = scheme == .dark ? Self.darkPlate : Self.lightPlate {
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
    private static let darkPlate = plate(dark: true)
    private static let lightPlate = plate(dark: false)

    private static func plate(dark: Bool) -> UIImage? {
        let glow = Color(white: dark ? 0.43 : 1)
        let lighting = ZStack {
            Color(white: dark ? 5.0 / 255 : 0.88)
            LinearGradient(colors: [.clear, Color(white: dark ? 0.12 : 0.68).opacity(dark ? 0.28 : 0.18), .clear],
                           startPoint: .topTrailing, endPoint: .bottomLeading)
            Ellipse()
                .fill(RadialGradient(colors: [glow.opacity(dark ? 0.40 : 0.86), glow.opacity(dark ? 0.17 : 0.38), .clear],
                                     center: .center, startRadius: 0, endRadius: 250))
                .frame(width: 500, height: 500)
                .scaleEffect(x: 1.9, y: 0.48)
                .rotationEffect(.degrees(-30))
                .blur(radius: 24)
                .offset(x: -42, y: 118)
            RadialGradient(colors: [Color(white: dark ? 0.33 : 1).opacity(dark ? 0.13 : 0.24), .clear],
                           center: UnitPoint(x: 0.95, y: 0.52), startRadius: 0, endRadius: 330)
            if let grain {
                Image(decorative: grain, scale: 1).resizable(resizingMode: .tile).opacity(0.012)
            }
        }.frame(width: 420, height: 900).clipped()
        let renderer = ImageRenderer(content: lighting)
        renderer.scale = 2
        renderer.isOpaque = true
        return renderer.uiImage
    }

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
