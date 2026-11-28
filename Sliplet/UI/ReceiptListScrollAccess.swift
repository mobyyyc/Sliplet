import SwiftUI
import UIKit

/// Native List keeps its cells, gestures and accessibility. This reference only restores
/// the saved pixel position after SwiftUI has brought the stable row identity into view.
@MainActor final class ReceiptListScrollAccess {
    weak var view: UIScrollView?
    // Tracking row geometry should not invalidate the List while it is scrolling.
    var rowFrames: [String: CGRect] = [:]
    var visibleTop: CGFloat {
        guard let view else { return 0 }
        return view.convert(CGPoint(x: view.bounds.minX, y: view.bounds.minY + view.adjustedContentInset.top), to: nil).y
    }
    func align(row: CGRect, to savedY: CGFloat) -> Bool {
        guard let view else { return false }
        let bottom = view.convert(CGPoint(x: view.bounds.minX, y: view.bounds.maxY - view.adjustedContentInset.bottom), to: nil).y
        let desired = max(visibleTop + 8, min(max(visibleTop + 8, bottom - row.height - 8), savedY))
        let minimum = -view.adjustedContentInset.top
        let maximum = max(minimum, view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom)
        let target = min(maximum, max(minimum, view.contentOffset.y + row.minY - desired))
        if abs(row.minY - desired) < 1.5 || abs(target - view.contentOffset.y) < 0.5 { return true }
        view.setContentOffset(CGPoint(x: view.contentOffset.x, y: target), animated: false)
        return false
    }
    func scrollToStart() {
        guard let view else { return }
        view.setContentOffset(CGPoint(x: view.contentOffset.x, y: -view.adjustedContentInset.top), animated: false)
    }
}

struct ReceiptListScrollProbe: UIViewRepresentable {
    var resolve: (UIScrollView) -> Void
    func makeUIView(context: Context) -> Probe { Probe(resolve: resolve) }
    func updateUIView(_ view: Probe, context: Context) { view.resolve = resolve; view.findScrollView() }
    final class Probe: UIView {
        var resolve: (UIScrollView) -> Void
        private weak var found: UIScrollView?
        init(resolve: @escaping (UIScrollView) -> Void) {
            self.resolve = resolve; super.init(frame: .zero)
            isUserInteractionEnabled = false; isAccessibilityElement = false
            backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() { super.didMoveToWindow(); findScrollView() }
        override func layoutSubviews() { super.layoutSubviews(); findScrollView() }
        func findScrollView() {
            guard window != nil else { return }
            var parent = superview
            while let current = parent {
                if let scroll = current as? UIScrollView {
                    if found !== scroll { found = scroll; resolve(scroll) }
                    return
                }
                parent = current.superview
            }
        }
    }
}
