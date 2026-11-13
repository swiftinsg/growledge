import SwiftUI

/// App entry point. The app always starts at ContentView, which decides
/// between the first-time questions and the Home tabs (never the Study page).
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
