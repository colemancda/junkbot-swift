// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Junkbot",
    targets: [
        .executableTarget(
            name: "Junkbot",
            path: "Sources/Junkbot",
            swiftSettings: [
                .unsafeFlags([
                    "-enable-experimental-feature", "Embedded",
                    "-enable-experimental-feature", "Extern",
                    "-wmo",
                    "-Osize",
                    "-disable-reflection-metadata",
                ])
            ]
        )
    ]
)
