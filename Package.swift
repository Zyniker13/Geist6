// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Geist6",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .executable(name: "inventory", targets: ["inventory"]),
        .library(name: "StripeSpec", targets: ["StripeSpec"]),
    ],
    targets: [
        .target(
            name: "StripeSpec",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "inventory",
            dependencies: ["StripeSpec"],
            path: "Tools/inventory"
        ),
    ]
)
