// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacASC",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacASC", targets: ["MacASC"])
    ],
    targets: [
        .executableTarget(
            name: "MacASC",
            path: "Sources"
        )
    ]
)
