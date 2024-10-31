import SwiftUI

@main
struct ScreensaverPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .edgesIgnoringSafeArea(.all) // Make content view extend to the edges of the screen.
                .frame(minWidth: 100, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                .onAppear {
                    // Automatically enter full screen mode
                    if let window = NSApplication.shared.windows.first {
                        window.toggleFullScreen(nil)
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle()) // Hide the title bar
        .commands {
            CommandGroup(replacing: .windowList) { }
        }
    }
}


struct ContentView: View {
    var body: some View {
        GeometryReader { geometry in
            ScreensaverViewRepresentable()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all) // Ignores the safe area to make the view full screen
        .onAppear {
            // Optional: Code to make the window full screen immediately on appear
            if let window = NSApplication.shared.windows.first {
                window.toggleFullScreen(nil)
            }
        }
    }
}

struct ScreensaverViewRepresentable: NSViewRepresentable {
    
    func makeNSView(context: Context) -> NSView {
        // Replace 'MainScreenSaverView' with the actual class of your screensaver
        let screensaverView = MainView(frame: .zero, isPreview: true)
        screensaverView?.startAnimation()
        return screensaverView ?? NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // The underlying view should handle its own updates if necessary
    }
}
