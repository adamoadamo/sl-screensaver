import SwiftUI
import ScreenSaver

@main
struct ScreensaverPreviewApp: App {
    var body: some Scene {
        WindowGroup("Full Screen Preview") {
            FullScreenContentView()
                .edgesIgnoringSafeArea(.all)
                .frame(minWidth: 100, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.toggleFullScreen(nil)
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .windowList) { }
        }

        // Add a second window for square preview
        WindowGroup("Square Preview") {
            SquareContentView()
                .frame(width: 800, height: 800)
                .background(Color.black)
                .onAppear {
                    if let window = NSApplication.shared.windows.last {
                        window.setContentSize(NSSize(width: 800, height: 800))
                        window.styleMask.remove(.resizable)
                        
                        // Center the window on screen
                        window.center()
                    }
                }
        }
    }
}

// Original full screen view
struct FullScreenContentView: View {
    var body: some View {
        GeometryReader { geometry in
            ScreensaverViewRepresentable()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black)
        .edgesIgnoringSafeArea(.all)
    }
}

// Add this struct to bridge between SwiftUI and the screensaver NSView
struct ScreensaverViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let screensaverView = MainView(frame: .zero, isPreview: true)
        screensaverView?.startAnimation()
        return screensaverView ?? NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Updates are handled by the screensaver view itself
    }
}

// New square view
struct SquareContentView: View {
    var body: some View {
        ScreensaverViewRepresentable()
            .frame(width: 800, height: 800)
            .background(Color.black)
    }
}
