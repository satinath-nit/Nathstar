// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nathstar",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "NorthstarCore", targets: ["NorthstarCore"]),
        .executable(name: "Nathstar", targets: ["NorthstarApp"])
    ],
    dependencies: [
        .package(path: "Vendor/SwiftTerm")
    ],
    targets: [
        .target(name: "NorthstarCore"),
        .executableTarget(
            name: "NorthstarApp",
            dependencies: [
                "NorthstarCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "NorthstarCoreChecks",
            dependencies: ["NorthstarCore"]
        )
    ]
)
