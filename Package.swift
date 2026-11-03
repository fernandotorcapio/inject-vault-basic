// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VaultCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "VaultCore", targets: ["VaultCore"])],
    targets: [
        .target(name: "VaultCore", path: "ios/VaultCore"),
        .testTarget(name: "VaultCoreTests", dependencies: ["VaultCore"], path: "ios/VaultCoreTests")
    ]
)
