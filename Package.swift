// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Indou",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "Indou", targets: ["Indou"]),
        .library(name: "IndouKit", targets: ["IndouKit"]),
    ],
    targets: [
        .target(
            name: "IndouKit",
            path: "Sources/IndouKit",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .target(
            name: "PrivateWindowServer",
            dependencies: ["IndouKit"],
            path: "Sources/PrivateWindowServer",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .executableTarget(
            name: "Indou",
            dependencies: ["IndouKit", "PrivateWindowServer"],
            path: "Sources/Indou",
            // Resources are placed into the .app by scripts/build-app.sh and loaded
            // via Bundle.main — not SwiftPM's Bundle.module (whose executable-target
            // accessor only looks next to the binary / build dir, which fails in a
            // distributed .app). Excluded here so SwiftPM doesn't generate that
            // fragile accessor.
            exclude: ["Resources"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "IndouKitTests",
            dependencies: ["IndouKit"],
            path: "Tests/IndouKitTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
