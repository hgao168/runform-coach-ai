import SwiftUI
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#endif

final class StravaPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = StravaPresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene,
                  windowScene.activationState == .foregroundActive else {
                continue
            }
            if let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return keyWindow
            }
        }

        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else {
                continue
            }
            if let firstWindow = windowScene.windows.first {
                return firstWindow
            }
        }

        return ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
