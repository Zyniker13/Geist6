// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Geist6",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .executable(name: "inventory", targets: ["inventory"]),
        .executable(name: "stripe-gen", targets: ["stripe-gen"]),
        .library(name: "StripeSpec", targets: ["StripeSpec"]),
        .library(name: "StripeModels", targets: ["StripeModels"]),
        .library(name: "StripeClient", targets: ["StripeClient"]),
    ],
    targets: [
        .target(
            name: "StripeSpec",
            resources: [.process("Resources")]
        ),
        .target(
            name: "StripeModels",
            dependencies: ["StripeSpec"]
        ),
        .target(
            name: "StripeClient",
            dependencies: ["StripeModels"]
        ),
        .executableTarget(
            name: "inventory",
            dependencies: ["StripeSpec"],
            path: "Tools/inventory"
        ),
        .executableTarget(
            name: "stripe-gen",
            dependencies: ["StripeSpec"],
            path: "Tools/stripe-gen"
        ),
        .testTarget(
            name: "ClientTests",
            dependencies: ["StripeClient"]
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["StripeModels"]
        ),
        .testTarget(
            name: "SpecTests",
            dependencies: ["StripeSpec"]
        ),
    ]
)
