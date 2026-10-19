import SwiftUI
import OceanPaySDK

@main
struct OceanDemoApp: App {
    var body: some Scene {
        WindowGroup {
            PaymentView()
                .onOpenURL { url in _ = OceanPaySDK.shared.handleOpenURL(url) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    _ = OceanPaySDK.shared.handleUniversalLink(activity)
                }
        }
    }
}
