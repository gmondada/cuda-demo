// swift-tools-version: 6.3;(experimentalCGen)
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "cuda-demo",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "cuda-demo",
            linkerSettings: [
                .unsafeFlags(["-L/usr/local/cuda/targets/x86_64-linux/lib"]),
                .linkedLibrary("cudadevrt"),
                .linkedLibrary("cudart_static"),
            ],
            plugins: [
                .plugin(name: "CudaBuild")
            ],
        ),
        .plugin(
            name: "CudaBuild",
            capability: .buildTool(),
            dependencies: [
                .target(name: "CudaLink"),
            ],
        ),
        .executableTarget(
            name: "CudaLink",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
        ),
    ],
    swiftLanguageModes: [.v6]
)
