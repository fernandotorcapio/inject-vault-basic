import SwiftUI

@main @MainActor struct InjectVaultApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).tint(Color(red: 0.08, green: 0.36, blue: 0.82))
        }
    }
}
