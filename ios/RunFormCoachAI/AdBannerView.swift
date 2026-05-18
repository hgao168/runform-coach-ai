import SwiftUI
import GoogleMobileAds

/// SwiftUI wrapper for GADBannerView using UIViewRepresentable.
struct AdBannerView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = context.coordinator.rootViewController
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject {
        let rootViewController: UIViewController

        override init() {
            // Acquire the topmost presented view controller as root for the banner
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                self.rootViewController = root
            } else {
                self.rootViewController = UIViewController()
            }
        }
    }
}

// MARK: - Test Ad Unit IDs

extension AdBannerView {
    /// Google-provided test banner ad unit ID (safe for development / TestFlight testing).
    static let testAdUnitID = "ca-app-pub-3940256099942544/2934735716"
}
