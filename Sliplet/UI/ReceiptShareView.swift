import CoreTransferable
import ImageIO
import Photos
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ReceiptShareImage: Transferable {
    let bytes: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.bytes }
            .suggestedFileName("Sliplet Receipt.png")
    }
}

@MainActor enum ReceiptShareRenderer {
    enum Failure: Error { case imageTooTall, renderingFailed }

    private static let background = CGColor(srgbRed: 1, green: 0.95, blue: 0.82, alpha: 1)

    static func render(_ receipt: ReceiptRecord) throws -> CGImage {
        let revision = receipt.current
        let isComplete = ReceiptCompletion.isComplete(receipt)
        var input = revision.reviewInput.flatMap { try? JSONDecoder().decode(ReceiptReviewDraft.self, from: $0) }
        if input == nil, isComplete {
            input = ReceiptReviewDraft(fields: revision.fields)
            input?.subtotalNotPrinted = revision.fields.subtotal == nil
        }
        let artwork = VStack(spacing: 0) {
            if !isComplete {
                Label("Draft · Needs review", systemImage: "exclamationmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
            }
            ReceiptPaper(fields: revision.fields, input: input, showsSurface: false,
                         taxedMarkers: receipt.original.paperTaxedMarkers)
            signature
        }
        .background {
            ReceiptPaperEdge().fill(.white)
                .overlay { ReceiptPaperEdge().stroke(.black.opacity(0.12), lineWidth: 0.6) }
                .shadow(color: .black.opacity(0.10), radius: 7, y: 4)
        }
        .padding(24)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Color(white: 0.10))
        .background(Color(cgColor: background))
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.receiptPaperAppearance, .alwaysWhite)

        let renderer = ImageRenderer(content: artwork)
        renderer.isOpaque = true
        var result: Result<CGImage, Failure> = .failure(.renderingFailed)
        renderer.render { size, draw in
            guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else { return }
            // Keep the full receipt at a readable resolution and bound the bitmap allocation.
            let scale = min(3, 32_000 / size.height, sqrt(24_000_000 / (size.width * size.height)))
            guard scale >= 1 else { result = .failure(.imageTooTall); return }
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: Int(ceil(size.width * scale)),
                    height: Int(ceil(size.height * scale)), bitsPerComponent: 8, bytesPerRow: 0,
                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return }
            context.setFillColor(background)
            context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
            context.scaleBy(x: scale, y: scale)
            draw(context)
            if let image = context.makeImage() { result = .success(image) }
        }
        return try result.get()
    }

    private static var signature: some View {
        HStack(spacing: 8) {
            if let icon = appIcon {
                Image(uiImage: icon)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            Text("Sliplet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(white: 0.25))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    static var appIcon: UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let names = primary["CFBundleIconFiles"] as? [String] else { return nil }
        return names.reversed().lazy.compactMap { UIImage(named: $0) }.first
    }

    nonisolated static func pngData(_ image: CGImage) throws -> Data {
        try Task.checkCancellation()
        let bytes = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(bytes, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure.renderingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Failure.renderingFailed }
        try Task.checkCancellation()
        return bytes as Data
    }
}

struct ReceiptShareButton: View {
    var identifier = "openReceiptShare"
    let action: () -> Void

    var body: some View {
        Button("Share receipt image", systemImage: "square.and.arrow.up", action: action)
            .labelStyle(.iconOnly)
            .accessibilityIdentifier(identifier)
    }
}

enum ReceiptSharePreviewMode: String, CaseIterable, Identifiable {
    case fit = "Fit"
    case fullWidth = "Full width"

    var id: Self { self }
}

struct ReceiptShareView: View {
    @Bindable var workspace: ReceiptWorkspace
    let receiptID: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var preview: Image?
    @State private var export: ReceiptShareImage?
    @State private var failureMessage: String?
    @State private var zoomTarget = UUID()
    @State private var mode: ReceiptSharePreviewMode = .fullWidth
    @State private var photoSave: Task<Void, Never>?
    @State private var savedToPhotos = false
    @State private var photoSaveIssue: PhotoSaveIssue?

    private enum PhotoSaveIssue: String, Identifiable {
        case denied, restricted, failed
        var id: Self { self }
    }

    private var record: ReceiptRecord? { workspace.receipts.first { $0.id == receiptID } }
    private var available: Bool { workspace.active && !workspace.privacyCovered }

    var body: some View {
        NavigationStack {
            Group {
                if !available {
                    ContentUnavailableView("Unlock to continue", systemImage: "lock")
                } else if let export {
                    VStack(spacing: 12) {
                        ZoomReceiptImage(bytes: export.bytes, boxes: [], reduceMotion: true,
                                         zoomTarget: zoomTarget, rasterID: "receiptShareImage", sharePreviewMode: mode)
                        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8))
                            : AnyLayout(HStackLayout(spacing: 12))
                        layout {
                            if typeSize.isAccessibilitySize {
                                previewModePicker.pickerStyle(.menu)
                            } else {
                                previewModePicker.pickerStyle(.segmented)
                            }
                            ReceiptSourceZoomControls(target: zoomTarget, prefix: "receiptShare", showsReset: false)
                        }
                    }
                    .padding(12)
                } else if let failureMessage {
                    ContentUnavailableView("Image unavailable", systemImage: "photo.badge.exclamationmark",
                                           description: Text(failureMessage))
                } else {
                    ProgressView("Preparing receipt image")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if available, let export {
                    VStack(spacing: 6) {
                        if savedToPhotos {
                            Label("Saved to Photos", systemImage: "checkmark.circle")
                                .font(.footnote).foregroundStyle(.secondary)
                                .accessibilityIdentifier("receiptSavedToPhotos")
                        }
                        Button {
                            saveToPhotos(export)
                        } label: {
                            if photoSave != nil {
                                ProgressView().accessibilityLabel("Saving to Photos")
                            } else {
                                Label("Save to Photos", systemImage: "photo.badge.arrow.down")
                            }
                        }
                        .buttonStyle(ReceiptProminentStyle())
                        .disabled(photoSave != nil)
                        .accessibilityIdentifier("saveReceiptToPhotos")
                    }
                    .modifier(ReceiptActionBarLayout())
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .alert(item: $photoSaveIssue) { issue in
                switch issue {
                case .denied:
                    Alert(title: Text("Allow saving to Photos"),
                          message: Text("Allow Sliplet to add photos in Settings, or use Share to save the image elsewhere."),
                          primaryButton: .default(Text("Open Settings")) {
                              if let settings = URL(string: UIApplication.openSettingsURLString) { openURL(settings) }
                          },
                          secondaryButton: .cancel())
                case .restricted:
                    Alert(title: Text("Photos access is restricted"),
                          message: Text("You can still use Share to save the image elsewhere."))
                case .failed:
                    Alert(title: Text("Couldn’t save to Photos"),
                          message: Text("Try again, or use Share to save the image elsewhere."))
                }
            }
            .navigationTitle("Share receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if available, let export, let preview {
                    ToolbarItem(placement: .confirmationAction) {
                        ShareLink(item: export, preview: SharePreview("Sliplet Receipt", image: preview)) {
                            Label("Share image", systemImage: "square.and.arrow.up")
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier("shareReceiptImage")
                    }
                }
            }
            .task(id: workspace.active ? record?.current.id : nil) {
                preview = nil
                export = nil
                failureMessage = nil
                mode = .fullWidth
                guard workspace.active else { return }
                guard let record else { failureMessage = "This receipt is no longer available."; return }
                do {
                    let image = try ReceiptShareRenderer.render(record)
                    let work = Task.detached(priority: .userInitiated) { try ReceiptShareRenderer.pngData(image) }
                    let bytes = try await withTaskCancellationHandler {
                        try await work.value
                    } onCancel: { work.cancel() }
                    try Task.checkCancellation()
                    guard workspace.active else { return }
                    export = ReceiptShareImage(bytes: bytes)
                    preview = Image(uiImage: UIImage(cgImage: image).preparingThumbnail(of: CGSize(width: 240, height: 240)) ?? UIImage(cgImage: image))
                } catch is CancellationError {
                } catch ReceiptShareRenderer.Failure.imageTooTall {
                    guard !Task.isCancelled else { return }
                    failureMessage = "This receipt is too long to share as a single readable image."
                } catch {
                    guard !Task.isCancelled else { return }
                    failureMessage = "Sliplet couldn’t prepare this receipt image."
                }
            }
        }.onDisappear { photoSave?.cancel() }
    }

    private func saveToPhotos(_ image: ReceiptShareImage) {
        guard photoSave == nil, available else { return }
        let session = workspace.sessionID
        let revision = record?.current.id
        savedToPhotos = false
        photoSave = Task {
            defer { photoSave = nil }
            var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            if status == .notDetermined {
                status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            }
            // The permission sheet can briefly make the scene inactive. A locked or
            // replaced wallet session still cancels the save before it reaches Photos.
            guard !Task.isCancelled, workspace.active, workspace.sessionID == session,
                  record?.current.id == revision else { return }
            switch status {
            case .authorized, .limited:
                do {
                    try await Self.addPhoto(image.bytes)
                    guard !Task.isCancelled, workspace.sessionID == session else { return }
                    savedToPhotos = true
                    AccessibilityNotification.Announcement("Saved to Photos").post()
                } catch {
                    guard !Task.isCancelled, workspace.sessionID == session else { return }
                    photoSaveIssue = .failed
                }
            case .denied: photoSaveIssue = .denied
            case .restricted: photoSaveIssue = .restricted
            case .notDetermined: break
            @unknown default: photoSaveIssue = .failed
            }
        }
    }

    // PhotoKit invokes this change block on its own queue.
    nonisolated private static func addPhoto(_ bytes: Data) async throws {
        let changes: @Sendable () -> Void = {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = "Sliplet Receipt.png"
            request.addResource(with: .photo, data: bytes, options: options)
        }
        try await PHPhotoLibrary.shared().performChanges(changes)
    }

    private var previewModePicker: some View {
        Picker("Preview size", selection: $mode) {
            ForEach(ReceiptSharePreviewMode.allCases) { setting in
                Text(setting.rawValue).tag(setting)
            }
        }.accessibilityIdentifier("receiptSharePreviewMode")
    }

}
