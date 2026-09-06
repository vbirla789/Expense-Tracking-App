import SwiftUI

@main
struct ExpensesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)   // light theme only
        }
    }
}
