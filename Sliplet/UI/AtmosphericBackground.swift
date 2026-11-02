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
        // The bend and uneven illumination keep the sweep from reading as a straight stripe.
        let sweep = Path { path in
            path.move(to: CGPoint(x: -70, y: 705))
            path.addCurve(to: CGPoint(x: 220, y: 514),
                          control1: CGPoint(x: 42, y: 585), control2: CGPoint(x: 129, y: 573))
            path.addCurve(to: CGPoint(x: 500, y: 253),
                          control1: CGPoint(x: 312, y: 469), control2: CGPoint(x: 359, y: 346))
        }
        let highlight = Color(white: dark ? 0.76 : 1)
        let ridge = LinearGradient(stops: [
            .init(color: highlight.opacity(0.16), location: 0),
            .init(color: highlight.opacity(0.30), location: 0.36),
            .init(color: highlight.opacity(dark ? 0.70 : 0.90), location: 0.68),
            .init(color: highlight.opacity(0.32), location: 1)
        ], startPoint: .leading, endPoint: .trailing)
        let lighting = ZStack {
            Color(white: dark ? 5.0 / 255 : 0.92)
            sweep.stroke(Color(white: dark ? 0.38 : 0.51).opacity(dark ? 0.56 : 0.40), lineWidth: 172)
                .offset(y: 31).blur(radius: 55)
            sweep.stroke(highlight.opacity(dark ? 0.20 : 0.40), lineWidth: 85)
                .blur(radius: 35)
            sweep.stroke(ridge, lineWidth: 32).blur(radius: 20)
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
