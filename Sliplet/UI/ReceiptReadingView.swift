import SwiftUI

struct ReceiptReadingView: View {
    let openingPhoto: Bool
    let usingAI: Bool
    let stop: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var stillReading = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    if usingAI {
                        ReceiptPrinter()
                            .frame(width: typeSize.isAccessibilitySize ? 160 : 208,
                                   height: typeSize.isAccessibilitySize ? 136 : 176)
                            .accessibilityHidden(true)
                    } else {
                        ProgressView().controlSize(.large).accessibilityHidden(true)
                    }

                    VStack(spacing: 6) {
                        Text(title)
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        if !openingPhoto {
                            Text(usingAI ? "Using Gemini" : "On your iPhone")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !openingPhoto {
                        Text("Keep Sliplet open. Review will open when reading finishes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 300)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeEffectStyle(.soft, for: .vertical)
        }
        .accessibilityIdentifier("processing")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if usingAI {
                    Text("Stopping won’t recall an image already sent to Google.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(openingPhoto ? "Cancel import" : "Stop reading", role: .cancel, action: stop)
                    .buttonStyle(ReceiptSecondaryStyle())
                    .accessibilityIdentifier("cancelImport")
            }
            .modifier(ReceiptActionBarLayout())
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .task(id: usingAI) {
            stillReading = false
            guard usingAI, (try? await Task.sleep(for: .seconds(8))) != nil, !Task.isCancelled else { return }
            stillReading = true
            AccessibilityNotification.Announcement("Still reading your receipt").post()
        }
    }

    private var title: String {
        if openingPhoto { return "Opening photo" }
        if stillReading { return "Still reading your receipt" }
        return usingAI ? "Reading your receipt" : "Reading receipt"
    }
}

private struct ReceiptPrinter: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var start = Date.now

    var body: some View {
        if ReceiptAccessibility.reduceMotion(reduceMotion) {
            illustration(feed: 0.78, paperOpacity: 1)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                let phase = max(0, context.date.timeIntervalSince(start)).truncatingRemainder(dividingBy: 2.2)
                let feed = 0.16 + 0.27 * advance(phase, after: 0.1)
                    + 0.27 * advance(phase, after: 0.48)
                    + 0.27 * advance(phase, after: 0.86)
                let opacity = 1 - advance(phase, after: 1.73, duration: 0.27)
                illustration(feed: feed, paperOpacity: opacity)
            }
        }
    }

    private func advance(_ time: Double, after delay: Double, duration: Double = 0.22) -> Double {
        let fraction = min(1, max(0, (time - delay) / duration))
        return fraction * fraction * (3 - 2 * fraction)
    }

    private func illustration(feed: Double, paperOpacity: Double) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let outlet = height * 0.42
            let paperWidth = width * 0.53
            let paperHeight = height * 0.54
            let dark = colorScheme == .dark

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: width * 0.12)
                    .fill(LinearGradient(colors: dark ? [Color(white: 0.30), Color(white: 0.15)]
                                                      : [Color(white: 0.94), Color(white: 0.78)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: width * 0.12)
                            .strokeBorder(.primary.opacity(0.14), lineWidth: 1)
                    }
                    .frame(width: width * 0.88, height: height * 0.49)
                    .padding(.top, height * 0.055)
                    .shadow(color: .black.opacity(dark ? 0.4 : 0.16), radius: 9, y: 5)

                Capsule()
                    .fill(.black.opacity(dark ? 0.82 : 0.67))
                    .frame(width: width * 0.66, height: height * 0.055)
                    .padding(.top, outlet - height * 0.021)

                VStack(alignment: .leading, spacing: height * 0.044) {
                    Capsule().fill(.black.opacity(0.29)).frame(width: paperWidth * 0.42, height: 3)
                    ForEach([0.73, 0.58, 0.68, 0.38], id: \.self) { fraction in
                        Capsule().fill(.black.opacity(0.17)).frame(width: paperWidth * fraction, height: 2)
                    }
                }
                .frame(width: paperWidth, height: paperHeight)
                .background {
                    ReceiptPaperEdge().fill(Color(white: 0.97))
                }
                .offset(y: outlet - paperHeight * (1 - feed))
                .frame(width: width, height: height, alignment: .top)
                .mask(alignment: .bottom) { Rectangle().frame(height: height - outlet) }
                .opacity(paperOpacity)

                Circle()
                    .fill(dark ? Color(white: 0.76) : Color(white: 0.39))
                    .frame(width: 5, height: 5)
                    .padding(.top, height * 0.19)
                    .offset(x: width * 0.29)
            }
            .frame(width: width, height: height, alignment: .top)
        }
    }
}
