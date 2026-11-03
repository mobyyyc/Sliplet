import SwiftUI
import UIKit

/// A zoomable image editor. All selections use normalized top-left coordinates.
struct ReceiptImportCanvas: UIViewRepresentable {
    let image: UIImage
    var cropMode = false
    var drawing = false
    var onEditBegan: () -> Void = {}
    @Binding var regions: [CGRect]
    @Binding var selected: Int?

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = ReceiptCanvasScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 5
        scroll.backgroundColor = .secondarySystemGroupedBackground
        scroll.layer.cornerRadius = 20; scroll.clipsToBounds = true
        let canvas = context.coordinator.canvas
        canvas.isUserInteractionEnabled = true
        canvas.accessibilityIdentifier = "uploadImage"
        canvas.accessibilityLabel = "Receipt photo. Pinch to zoom."
        scroll.addSubview(canvas)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.draw(_:)))
        pan.maximumNumberOfTouches = 1
        pan.isEnabled = drawing; canvas.addGestureRecognizer(pan)
        context.coordinator.drawGesture = pan
        context.coordinator.scroll = scroll
        scroll.layoutHandler = { [weak coordinator = context.coordinator] in coordinator?.fitIfNeeded() }
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let c = context.coordinator; c.parent = self
        c.drawGesture?.isEnabled = drawing
        scroll.panGestureRecognizer.minimumNumberOfTouches = drawing ? 2 : 1
        if c.canvas.image !== image {
            scroll.setZoomScale(1, animated: false)
            c.canvas.image = image
            c.fitted = false
        }
        DispatchQueue.main.async { c.fitIfNeeded(); if !c.dragging { c.render() } }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ReceiptImportCanvas
        let canvas = UIImageView()
        weak var scroll: UIScrollView?
        var drawGesture: UIPanGestureRecognizer?
        var fitted = false
        var viewport = CGSize.zero
        var dragging = false
        var start = CGPoint.zero
        var initial = CGRect.zero
        var overlays: [UIView] = []
        init(_ parent: ReceiptImportCanvas) { self.parent = parent }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { center() }
        func center() {
            guard let scroll else { return }
            scroll.contentInset = UIEdgeInsets(top: max(0, (scroll.bounds.height - canvas.frame.height) / 2),
                left: max(0, (scroll.bounds.width - canvas.frame.width) / 2), bottom: 0, right: 0)
        }
        func fitIfNeeded() {
            guard let scroll, scroll.bounds.width > 0, scroll.bounds.height > 0,
                  !fitted || viewport != scroll.bounds.size else { return }
            viewport = scroll.bounds.size; fitted = true
            scroll.setZoomScale(1, animated: false)
            let ratio = min(scroll.bounds.width / parent.image.size.width, scroll.bounds.height / parent.image.size.height)
            canvas.frame = CGRect(origin: .zero, size: CGSize(width: parent.image.size.width * ratio, height: parent.image.size.height * ratio))
            scroll.contentSize = canvas.bounds.size; fitted = true; center()
        }
        func point(_ gesture: UIGestureRecognizer) -> CGPoint {
            let p = gesture.location(in: canvas)
            return CGPoint(x: min(1, max(0, p.x / max(1, canvas.bounds.width))),
                           y: min(1, max(0, p.y / max(1, canvas.bounds.height))))
        }
        @objc func draw(_ gesture: UIPanGestureRecognizer) {
            let p = point(gesture)
            if gesture.state == .began {
                parent.onEditBegan(); dragging = true; start = p
                if parent.cropMode { parent.regions = [CGRect(x: p.x, y: p.y, width: 0.02, height: 0.02)]; parent.selected = 0 }
                else {
                    guard parent.regions.count < 98 else { dragging = false; return }
                    parent.regions.append(CGRect(x: p.x, y: p.y, width: 0.02, height: 0.02)); parent.selected = parent.regions.count - 1
                }
            }
            guard dragging, let index = parent.selected, parent.regions.indices.contains(index) else { return }
            let x = min(start.x, p.x), y = min(start.y, p.y)
            parent.regions[index] = CGRect(x: x, y: y, width: min(1 - x, max(0.02, abs(start.x - p.x))),
                                          height: min(1 - y, max(0.02, abs(start.y - p.y))))
            if gesture.state == .ended || gesture.state == .cancelled { dragging = false }
            render()
        }
        @objc func selectRegion(_ gesture: UITapGestureRecognizer) {
            parent.selected = gesture.view?.tag; render()
        }
        @objc func edit(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let index = view.tag / 10, corner = view.tag % 10
            guard parent.regions.indices.contains(index) else { return }
            let p = point(gesture)
            if gesture.state == .began { parent.onEditBegan(); dragging = true; start = p; initial = parent.regions[index]; parent.selected = index }
            let dx = p.x - start.x, dy = p.y - start.y
            if corner == 0 {
                parent.regions[index] = CGRect(x: min(1 - initial.width, max(0, initial.minX + dx)),
                    y: min(1 - initial.height, max(0, initial.minY + dy)), width: initial.width, height: initial.height)
            } else {
                let left = corner == 1 || corner == 3, top = corner == 1 || corner == 2
                let x0 = left ? min(initial.maxX - 0.02, max(0, initial.minX + dx)) : initial.minX
                let y0 = top ? min(initial.maxY - 0.02, max(0, initial.minY + dy)) : initial.minY
                let x1 = left ? initial.maxX : max(initial.minX + 0.02, min(1, initial.maxX + dx))
                let y1 = top ? initial.maxY : max(initial.minY + 0.02, min(1, initial.maxY + dy))
                parent.regions[index] = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            }
            // Keep gesture views alive during manipulation; reposition them in place.
            positionOverlays()
            if gesture.state == .ended || gesture.state == .cancelled { dragging = false; render() }
        }
        func render() {
            guard !dragging || drawGesture?.state == .changed || drawGesture?.state == .began else { return }
            overlays.forEach { $0.removeFromSuperview() }; overlays = []
            for (index, _) in parent.regions.enumerated() {
                let box = UIView(); box.tag = index * 10
                box.backgroundColor = parent.cropMode ? UIColor.black.withAlphaComponent(0.08) : .black
                box.layer.borderWidth = 2; box.layer.borderColor = (parent.selected == index ? UIColor.systemBlue : UIColor.white).cgColor
                box.isUserInteractionEnabled = !parent.drawing
                box.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(edit(_:))))
                let tap = UITapGestureRecognizer(target: self, action: #selector(tapBox(_:)))
                box.addGestureRecognizer(tap)
                box.isAccessibilityElement = true; box.accessibilityLabel = parent.cropMode ? "Crop selection" : "Hidden area \(index + 1)"
                canvas.addSubview(box); overlays.append(box)
                if parent.selected == index {
                    for corner in 1...4 {
                        let handle = UIView(); handle.tag = index * 10 + corner
                        handle.backgroundColor = .clear
                        let dot = UIView(frame: CGRect(x: 16, y: 16, width: 12, height: 12))
                        dot.backgroundColor = .systemBlue; dot.layer.cornerRadius = 6; dot.isUserInteractionEnabled = false
                        handle.addSubview(dot)
                        handle.accessibilityIdentifier = "importHandle-\(index)-\(corner)"
                        handle.isUserInteractionEnabled = !parent.drawing
                        handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(edit(_:))))
                        canvas.addSubview(handle); overlays.append(handle)
                    }
                }
            }
            positionOverlays()
        }
        @objc func tapBox(_ gesture: UITapGestureRecognizer) { parent.selected = (gesture.view?.tag ?? 0) / 10; render() }
        func positionOverlays() {
            for view in overlays {
                let index = view.tag / 10, corner = view.tag % 10
                guard parent.regions.indices.contains(index) else { continue }
                let r = parent.regions[index]
                let rect = CGRect(x: r.minX * canvas.bounds.width, y: r.minY * canvas.bounds.height,
                                  width: r.width * canvas.bounds.width, height: r.height * canvas.bounds.height)
                if corner == 0 { view.frame = rect }
                else {
                    let x = corner == 1 || corner == 3 ? rect.minX : rect.maxX
                    let y = corner == 1 || corner == 2 ? rect.minY : rect.maxY
                    view.frame = CGRect(x: x - 22, y: y - 22, width: 44, height: 44)
                }
            }
        }
    }
}

private final class ReceiptCanvasScrollView: UIScrollView {
    var layoutHandler: (() -> Void)?
    override func layoutSubviews() {
        super.layoutSubviews()
        layoutHandler?()
    }
}
