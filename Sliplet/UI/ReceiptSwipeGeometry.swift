import Foundation

/// A gesture starting with a revealed action can only continue or close that side.
enum ReceiptSwipeGeometry {
    static func offset(start: CGFloat, translation: CGFloat, leftEnabled: Bool, rightEnabled: Bool) -> CGFloat {
        let value = max(-180, min(180, start + translation))
        if start < 0 { return min(0, value) }
        if start > 0 { return max(0, value) }
        return value < 0 ? (leftEnabled ? value : 0) : (rightEnabled ? value : 0)
    }
    static func settled(_ offset: CGFloat) -> CGFloat { abs(offset) > 42 ? (offset < 0 ? -108 : 108) : 0 }
}
