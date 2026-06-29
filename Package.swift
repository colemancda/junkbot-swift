// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Junkbot",
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.56.0")
    ],
    targets: [
        .target(
            name: "JunkbotCore"
        ),
        .executableTarget(
            name: "JunkbotApp",
            dependencies: [
                "JunkbotCore",
                .product(name: "JavaScriptKit", package: "JavaScriptKit")
            ],
            swiftSettings: [
                .unsafeFlags(["-wmo", "-Osize"])
            ]
        )
    ]
)
