import AppKit
import RasterCore
import SwiftUI

extension AppSettings {
    /// Binding die via `set(_:_:)` wijzigt, zodat de voorkeur bewaard en toegepast wordt.
    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { self[keyPath: keyPath] }, set: { self.set(keyPath, $0) })
    }

    /// Als `binding(_:)`, afgerond op een veelvoud van `step` (een Stepper of Slider telt anders 0,30000000004).
    func binding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Double>, step: Double) -> Binding<Double> {
        Binding(get: { self[keyPath: keyPath] }, set: { self.set(keyPath, ($0 / step).rounded() / (1 / step)) })
    }

    /// Kleurkiezer ↔ sRGB-kleur.
    func colorBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, RasterCore.RGBColor>) -> Binding<Color> {
        Binding(get: {
            let color = self[keyPath: keyPath]
            return Color(.sRGB, red: color.red, green: color.green, blue: color.blue)
        }, set: { color in
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            self.set(keyPath, RasterCore.RGBColor(
                red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent)))
        })
    }
}
