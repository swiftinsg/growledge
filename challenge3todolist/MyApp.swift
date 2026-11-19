import SwiftUI

/// App entry point. The app always starts at ContentView, which decides
/// between the first-time questions and the Home tabs (never the Study page).
@main struct MyApp: App {
    init() {
        // The system keeps app blocks after the app closes. A timer never
        // survives a relaunch, so start clean: closing Growledge can't leave
        // the phone locked.
        FocusLock.releaseShield()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
