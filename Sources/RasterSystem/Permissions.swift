import AppKit
import ApplicationServices

@MainActor
public enum Permissions {
    public static var accessibility: Bool { AXIsProcessTrusted() }

    /// Toont de systeemvraag en zet Raster in de lijst van Toegankelijkheid.
    public static func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static func openAccessibilitySettings() {
        // Het oude adres (com.apple.preference.security) opent op macOS 27 een leeg paneel.
        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Controleert elke 2 seconden of de toestemming er is en roept dan één keer `onTrusted` aan.
@MainActor
public final class AccessibilityWatcher {
    private var task: Task<Void, Never>?

    public init() {}

    public func waitForTrust(_ onTrusted: @escaping @MainActor () -> Void) {
        task?.cancel()
        task = Task { @MainActor in
            while !Task.isCancelled {
                if AXIsProcessTrusted() {
                    onTrusted()
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }
}
