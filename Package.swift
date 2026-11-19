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
        .library(name: "GeistMetrics", targets: ["GeistMetrics"]),
        .library(name: "GeistData", targets: ["GeistData"]),
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
        .target(
            name: "GeistMetrics",
            dependencies: ["StripeModels"]
        ),
        .target(
            name: "GeistData",
            dependencies: ["StripeModels", "StripeClient", "GeistMetrics"]
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
            dependencies: ["StripeClient", "GeistData"]
        ),
        .testTarget(
            name: "ModelsTests",
            dependencies: ["StripeModels"]
        ),
        .testTarget(
            name: "SpecTests",
            dependencies: ["StripeSpec"]
        ),
        .testTarget(
            name: "GeistMetricsTests",
            dependencies: ["GeistMetrics"]
        ),
        .testTarget(
            name: "GeistDataTests",
            dependencies: ["GeistData"]
        ),
    ]
)
