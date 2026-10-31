import SwiftUI
import UIKit

/// Scene notifications are used explicitly: scene-based apps need not call legacy app callbacks.
@MainActor enum ReceiptPrivacyCover {
    private static var covers: [UIHostingController<ReceiptLockScreen>] = []
    static var isCovered: Bool { !covers.isEmpty }
    static func show(_ application: UIApplication = .shared) {
        guard covers.isEmpty else { return }
        for window in application.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows) {
            let host = UIHostingController(rootView: ReceiptLockScreen())
            let cover = host.view!
            cover.frame = window.bounds
            cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cover.backgroundColor = .systemGroupedBackground
            cover.isOpaque = true
            cover.accessibilityViewIsModal = true
            cover.accessibilityIdentifier = "privacyCover"
            window.addSubview(cover)
            cover.layoutIfNeeded()
            covers.append(host)
        }
    }
    static func hide() { covers.forEach { $0.view.removeFromSuperview() }; covers = [] }
}

@MainActor final class ReceiptPrivacyDelegate: NSObject, UIApplicationDelegate {
    private var tokens: [NSObjectProtocol] = []
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        tokens = [UIScene.willDeactivateNotification, UIApplication.protectedDataWillBecomeUnavailableNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    ReceiptPrivacyCover.show()
                    #if DEBUG
                    WorkflowTestInput.recordPrivacy(event: name == UIScene.willDeactivateNotification ? "sceneDeactivated" : "protectedDataUnavailable", covered: ReceiptPrivacyCover.isCovered)
                    #endif
                }
            }
        }
        tokens.append(NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                if UIApplication.shared.isProtectedDataAvailable { ReceiptPrivacyCover.hide() }
            }
        })
        return true
    }
    func applicationWillResignActive(_ application: UIApplication) { ReceiptPrivacyCover.show(application) }
    func applicationDidBecomeActive(_ application: UIApplication) { if application.isProtectedDataAvailable { ReceiptPrivacyCover.hide() } }
    func applicationProtectedDataDidBecomeAvailable(_ application: UIApplication) {
        if application.applicationState == .active { ReceiptPrivacyCover.hide() }
    }
    func applicationProtectedDataWillBecomeUnavailable(_ application: UIApplication) { ReceiptPrivacyCover.show(application) }
}
