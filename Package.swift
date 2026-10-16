// swift-tools-version: 6.0
import PackageDescription

/// We linken bewust met SDK-versie 15.2, zodat AppKit de compacte klassieke vormgeving gebruikt (kleinere
/// bedieningselementen, zoals verkeerslichten, mini-schakelaar 26 × 15, witte stepper en pop-up met blauw vakje)
/// waar de layout op is afgestemd. Minimaal macOS 27.0, SDK-versie 15.2
/// (controle: `otool -l .build/debug/Raster | grep -A4 LC_BUILD_VERSION`).
let legacyAppearance: [LinkerSetting] = [
    .unsafeFlags(["-Xlinker", "-platform_version", "-Xlinker", "macos", "-Xlinker", "27.0", "-Xlinker", "15.2"]),
]

let package = Package(
    name: "Raster",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "Raster", targets: ["Raster"]),
        // Tekent de interface offscreen naar PNG's voor snapshots van de interface (zie Sources/RasterRender/main.swift).
        .executable(name: "raster-render", targets: ["RasterRender"]),
    ],
    targets: [
        .target(name: "RasterCore"),
        .target(name: "RasterSystem", dependencies: ["RasterCore"]),
        // Alles van de app behalve het startpunt, zodat de tests en `raster-render` het kunnen gebruiken.
        .target(name: "RasterUI", dependencies: ["RasterCore", "RasterSystem"]),
        .executableTarget(name: "Raster", dependencies: ["RasterUI"], linkerSettings: legacyAppearance),
        // Eigen programma en geen test: het testproces is met de nieuwe SDK gelinkt en tekent dus de nieuwe vormgeving.
        .executableTarget(name: "RasterRender", dependencies: ["RasterUI", "RasterCore"],
                          linkerSettings: legacyAppearance),
        .testTarget(name: "RasterCoreTests", dependencies: ["RasterCore"]),
        .testTarget(name: "RasterSystemTests", dependencies: ["RasterCore", "RasterSystem"]),
        .testTarget(name: "RasterUITests", dependencies: ["RasterUI", "RasterCore"]),
    ]
)
