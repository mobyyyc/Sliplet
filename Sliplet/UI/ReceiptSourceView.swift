import SwiftUI
import UIKit
import ImageIO

struct ReceiptSourceView: View {
    @Bindable var workspace: ReceiptWorkspace
    @State private var mode = 0
    @State private var zoomTarget = UUID()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var reduceMotion: Bool { ReceiptAccessibility.reduceMotion(systemReduceMotion) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Evidence", selection: $mode) {
                    Text("Original image").tag(0)
                    Text("Printed text").tag(1)
                }.pickerStyle(.segmented).padding().accessibilityIdentifier("sourceMode")
                if workspace.privacyCovered || !workspace.active {
                    ContentUnavailableView("Original locked", systemImage: "lock")
                } else if mode == 0, let image = workspace.image {
                    ZoomReceiptImage(bytes: image.bytes, boxes: (workspace.extraction?.rawOCR ?? []).filter { workspace.sourceLineIDs.contains($0.id) }.compactMap(\.boundingBox), reduceMotion: reduceMotion, zoomTarget: zoomTarget, rasterID: "sourceRaster")
                        .accessibilityIdentifier("sourceImage")
                    Text("Pinch, double-tap or use the zoom buttons. Highlights show where a line was read.")
                        .font(.footnote).foregroundStyle(.primary).padding()
                    ReceiptSourceZoomControls(target: zoomTarget, prefix: "source").padding(.bottom)
                } else {
                    List {
                        Section { Text("Text read from the original may contain errors or omissions. Check against the image.").font(.footnote) }
                        ForEach(workspace.extraction?.rawOCR ?? []) { line in
                            Text(line.text).textSelection(.enabled)
                                .listRowBackground(workspace.sourceLineIDs.contains(line.id) ? Color(uiColor: .tertiarySystemFill) : Color(uiColor: .secondarySystemGroupedBackground))
                        }
                        if workspace.extraction?.rawOCR.isEmpty ?? true { Text("No recognized text. Compare against the original image.") }
                    }
                }
            }.navigationTitle("Original evidence").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { workspace.sourceVisible = false; dismiss() }.accessibilityIdentifier("sourceDone") } }
        }.tint(.primary).accessibilityIdentifier("sourceScreen")
    }
}

extension Notification.Name {
    static let receiptZoomIn = Notification.Name("Sliplet.sourceZoomIn")
    static let receiptZoomOut = Notification.Name("Sliplet.sourceZoomOut")
    static let receiptZoomReset = Notification.Name("Sliplet.sourceZoomReset")
}

/// In-memory UIKit image view; no file output, disk thumbnails or web cache.
struct ZoomReceiptImage: UIViewRepresentable {
    let bytes: Data
    let boxes: [ReceiptOCRBox]
    let reduceMotion: Bool
    let zoomTarget: UUID
    let rasterID: String
    var selection: Binding<ReceiptOCRBox>? = nil
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let view = ReceiptZoomScrollView()
        view.backgroundColor = .systemBackground
        view.contentInsetAdjustmentBehavior = .never
        view.delegate = context.coordinator
        view.maximumZoomScale = 8; view.minimumZoomScale = 0.01
        let coordinator = context.coordinator
        coordinator.scrollView = view
        coordinator.selection = selection
        view.panGestureRecognizer.minimumNumberOfTouches = selection == nil ? 1 : 2
        let draw = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.selectArea(_:)))
        draw.maximumNumberOfTouches = 1; draw.isEnabled = selection != nil
        view.addGestureRecognizer(draw); coordinator.selectionGesture = draw
        let imageView = coordinator.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.accessibilityLabel = "Original receipt image"
        imageView.accessibilityIdentifier = rasterID
        imageView.accessibilityHint = "Pinch, double tap, or use the zoom buttons. Printed text provides an OCR alternative."
        view.addSubview(imageView)
        coordinator.spinner.hidesWhenStopped = true
        coordinator.spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coordinator.spinner)
        coordinator.failureLabel.numberOfLines = 0; coordinator.failureLabel.textAlignment = .center
        coordinator.failureLabel.font = .preferredFont(forTextStyle: .body)
        coordinator.failureLabel.adjustsFontForContentSizeCategory = true
        coordinator.failureLabel.translatesAutoresizingMaskIntoConstraints = false
        coordinator.failureLabel.isHidden = true
        view.addSubview(coordinator.failureLabel)
        NSLayoutConstraint.activate([
            coordinator.spinner.centerXAnchor.constraint(equalTo: view.frameLayoutGuide.centerXAnchor),
            coordinator.spinner.centerYAnchor.constraint(equalTo: view.frameLayoutGuide.centerYAnchor),
            coordinator.failureLabel.centerYAnchor.constraint(equalTo: view.frameLayoutGuide.centerYAnchor),
            coordinator.failureLabel.leadingAnchor.constraint(equalTo: view.frameLayoutGuide.leadingAnchor, constant: 24),
            coordinator.failureLabel.trailingAnchor.constraint(equalTo: view.frameLayoutGuide.trailingAnchor, constant: -24)
        ])
        view.layoutReady = { [weak coordinator, weak view] in
            guard let coordinator, let view else { return }
            coordinator.fit(view)
        }
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2; view.addGestureRecognizer(tap)
        coordinator.reduceMotion = reduceMotion; coordinator.zoomTarget = zoomTarget
        coordinator.observeZoom(); coordinator.update(bytes: bytes, boxes: boxes)
        return view
    }
    func updateUIView(_ view: UIScrollView, context: Context) {
        context.coordinator.reduceMotion = reduceMotion; context.coordinator.zoomTarget = zoomTarget
        context.coordinator.selection = selection
        context.coordinator.selectionGesture?.isEnabled = selection != nil
        view.panGestureRecognizer.minimumNumberOfTouches = selection == nil ? 1 : 2
        context.coordinator.update(bytes: bytes, boxes: boxes)
        context.coordinator.fit(view)
    }
    static func dismantleUIView(_ view: UIScrollView, coordinator: Coordinator) {
        coordinator.stopObserving(); view.delegate = nil
        (view as? ReceiptZoomScrollView)?.layoutReady = nil
        coordinator.imageView.image = nil; coordinator.imageView.subviews.forEach { $0.removeFromSuperview() }
    }
    @MainActor final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        let spinner = UIActivityIndicatorView(style: .medium)
        let failureLabel = UILabel()
        weak var scrollView: UIScrollView?
        var fitted = false
        var reduceMotion = false
        var boxes: [ReceiptOCRBox] = []
        var zoomTarget = UUID()
        var selection: Binding<ReceiptOCRBox>?
        weak var selectionGesture: UIPanGestureRecognizer?
        private var selectionStart: CGPoint?
        private var tokens: [NSObjectProtocol] = []
        private var displayTask: Task<Void, Never>?
        private var loadedBytes: Data?
        private var generation = UUID()
        private var viewport = CGSize.zero
        func update(bytes: Data, boxes: [ReceiptOCRBox]) {
            let differentBoxes = self.boxes != boxes
            self.boxes = boxes
            guard loadedBytes != bytes else {
                if differentBoxes, imageView.image != nil { drawHighlights(); if selection == nil { focus() } }
                return
            }
            loadedBytes = bytes; generation = UUID(); let token = generation
            displayTask?.cancel(); failureLabel.isHidden = true; spinner.startAnimating(); imageView.isAccessibilityElement = false
            displayTask = Task { [weak self] in
                let work = Task.detached(priority: .userInitiated) { ReceiptDisplayImage.raster(bytes) }
                let raster = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
                guard let self, !Task.isCancelled, self.generation == token, let view = self.scrollView else { return }
                self.spinner.stopAnimating()
                guard let raster else {
                    self.failureLabel.text = "Couldn’t display the original. Close and reopen this receipt."
                    self.failureLabel.isHidden = false
                    return
                }
                view.minimumZoomScale = 0.01; view.setZoomScale(1, animated: false)
                self.imageView.image = UIImage(cgImage: raster)
                self.imageView.isAccessibilityElement = true
                self.imageView.frame = CGRect(x: 0, y: 0, width: raster.width, height: raster.height)
                view.contentSize = self.imageView.bounds.size
                self.fitted = false; self.viewport = .zero
                self.drawHighlights(); self.fit(view)
            }
        }
        @objc func selectArea(_ gesture: UIPanGestureRecognizer) {
            guard let selection, imageView.image != nil else { return }
            let size = imageView.bounds.size
            guard size.width > 0, size.height > 0 else { return }
            let raw = gesture.location(in: imageView)
            let point = CGPoint(x: min(max(0, raw.x), size.width), y: min(max(0, raw.y), size.height))
            if gesture.state == .began {
                // A pan begins only after its movement threshold. Recover the original
                // touch so the selected rectangle starts where the user put their finger.
                let translation = gesture.translation(in: imageView)
                selectionStart = CGPoint(x: min(max(0, raw.x - translation.x), size.width),
                                         y: min(max(0, raw.y - translation.y), size.height))
            }
            guard let start = selectionStart else { return }
            let rect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y), width: abs(start.x-point.x), height: abs(start.y-point.y))
            if rect.width / size.width >= 0.02, rect.height / size.height >= 0.01,
               let box = try? ReceiptOCRBox(x: rect.minX/size.width, y: 1-rect.maxY/size.height,
                                           width: rect.width/size.width, height: rect.height/size.height) {
                selection.wrappedValue = box
            }
            if gesture.state == .ended || gesture.state == .cancelled { selectionStart = nil }
        }
        func drawHighlights() {
            imageView.subviews.forEach { $0.removeFromSuperview() }
            let size = imageView.bounds.size
            for box in boxes {
                let region = UIView(frame: CGRect(x: box.x * size.width, y: (1 - box.y - box.height) * size.height,
                                                 width: box.width * size.width, height: box.height * size.height))
                region.layer.borderColor = UIColor.systemBlue.cgColor; region.layer.borderWidth = max(2, size.width / 250)
                region.isUserInteractionEnabled = false; region.isAccessibilityElement = false
                imageView.addSubview(region)
            }
        }
        func fit(_ view: UIScrollView) {
            guard imageView.image != nil, view.bounds.width > 0, view.bounds.height > 0, viewport != view.bounds.size else { return }
            let initial = !fitted
            let relativeZoom = fitted ? view.zoomScale / max(0.001, view.minimumZoomScale) : 1
            let position = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: imageView)
            viewport = view.bounds.size; fitted = true
            let fit = view.bounds.width / max(1, imageView.bounds.width)
            view.minimumZoomScale = fit; view.maximumZoomScale = max(fit * 8, 2)
            view.setZoomScale(min(view.maximumZoomScale, fit * relativeZoom), animated: false)
            if initial { focus() }
            else {
                view.setContentOffset(CGPoint(x: min(max(0, position.x * view.zoomScale - view.bounds.width / 2), max(0, view.contentSize.width - view.bounds.width)),
                                              y: min(max(0, position.y * view.zoomScale - view.bounds.height / 2), max(0, view.contentSize.height - view.bounds.height))), animated: false)
            }
            describePosition(view)
        }
        func focus() {
            guard fitted, let view = scrollView,
                  let region = ReceiptSourceGeometry.focus(boxes: boxes, size: imageView.bounds.size) else { return }
            view.zoom(to: region, animated: false); describePosition(view)
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { describePosition(scrollView) }
        func scrollViewDidScroll(_ scrollView: UIScrollView) { describePosition(scrollView) }
        func describePosition(_ view: UIScrollView) {
            let range = max(1, view.contentSize.height - view.bounds.height)
            let position = Int(min(100, max(0, view.contentOffset.y / range * 100)))
            imageView.accessibilityValue = "Zoom \(Int(view.zoomScale * 100)) percent, image position \(position) percent"
            let visible = view.convert(view.bounds, to: imageView).intersection(imageView.bounds)
            if !visible.isNull && !visible.isEmpty { imageView.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(visible, in: imageView) }
        }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = scrollView, imageView.image != nil else { return }
            let animate = !reduceMotion && !UIAccessibility.isReduceMotionEnabled
            if view.zoomScale > view.minimumZoomScale * 1.5 { view.setZoomScale(view.minimumZoomScale, animated: animate) }
            else {
                let point = gesture.location(in: imageView), scale = min(view.maximumZoomScale, view.minimumZoomScale * 3)
                let size = CGSize(width: view.bounds.width / scale, height: view.bounds.height / scale)
                view.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: animate)
            }
        }
        func observeZoom() {
            tokens = [(.receiptZoomIn, 1.6), (.receiptZoomOut, 1 / 1.6), (.receiptZoomReset, 0)].map { name, factor in
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                    let target = notification.userInfo?["target"] as? UUID
                    MainActor.assumeIsolated {
                        guard let self, target == self.zoomTarget, let view = self.scrollView else { return }
                        if factor == 0 {
                            view.setZoomScale(view.minimumZoomScale, animated: false); view.setContentOffset(.zero, animated: false)
                        } else {
                            view.setZoomScale(min(view.maximumZoomScale, max(view.minimumZoomScale, view.zoomScale * factor)), animated: !self.reduceMotion && !UIAccessibility.isReduceMotionEnabled)
                        }
                    }
                }
            }
        }
        func stopObserving() {
            generation = UUID(); displayTask?.cancel(); displayTask = nil; loadedBytes = nil
            tokens.forEach(NotificationCenter.default.removeObserver); tokens = []
            spinner.stopAnimating()
        }
    }
}

@MainActor private final class ReceiptZoomScrollView: UIScrollView {
    var layoutReady: (() -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); layoutReady?() }
}

/// Display-only ImageIO decoding applies EXIF orientation and bounded memory off the UI thread.
/// The entire receipt remains represented; stored bytes and evidence boxes are never rewritten.
enum ReceiptDisplayImage {
    nonisolated static func raster(_ bytes: Data) -> CGImage? {
        guard !Task.isCancelled, let source = CGImageSourceCreateWithData(bytes as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let h = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              w > 0, h > 0, w.isFinite, h.isFinite else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let width = (5...8).contains(orientation) ? h : w
        let height = (5...8).contains(orientation) ? w : h
        let factor = min(1, 2048 / width, sqrt(16_000_000 / (width * height)), 32768 / max(width, height))
        let longest = Int(ceil(max(width, height) * factor))
        guard !Task.isCancelled else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: longest,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
    @MainActor static func make(_ bytes: Data) -> UIImage? { raster(bytes).map { UIImage(cgImage: $0) } }
}


struct ReceiptSourceZoomControls: View {
    let target: UUID
    let prefix: String
    private func signal(_ name: Notification.Name) { NotificationCenter.default.post(name: name, object: nil, userInfo: ["target": target]) }
    var body: some View {
        HStack {
            Button("Zoom in", systemImage: "plus.magnifyingglass") { signal(.receiptZoomIn) }.accessibilityIdentifier(prefix + "ZoomIn")
            Button("Zoom out", systemImage: "minus.magnifyingglass") { signal(.receiptZoomOut) }.accessibilityIdentifier(prefix + "ZoomOut")
            Button("Reset zoom", systemImage: "arrow.down.right.and.arrow.up.left") { signal(.receiptZoomReset) }.accessibilityIdentifier(prefix + "ZoomReset")
        }.labelStyle(.iconOnly).buttonStyle(ReceiptSecondaryStyle())
    }
}

/// A display-only region. Neither source coordinates nor encoded original bytes are rewritten.
enum ReceiptSourceGeometry {
    static func focus(boxes: [ReceiptOCRBox], size: CGSize) -> CGRect? {
        guard size.width > 0, size.height > 0, !boxes.isEmpty else { return nil }
        let bounds = CGRect(origin: .zero, size: size)
        let union = boxes.reduce(CGRect.null) { region, box in
            region.union(CGRect(x: box.x * size.width, y: (1 - box.y - box.height) * size.height,
                               width: box.width * size.width, height: box.height * size.height))
        }.intersection(bounds)
        guard !union.isNull, !union.isEmpty else { return nil }
        // Keep surrounding context; the full image remains scrollable and resettable.
        return union.insetBy(dx: -size.width * 0.08, dy: -max(size.width * 0.12, union.height * 0.5)).intersection(bounds)
    }
}
