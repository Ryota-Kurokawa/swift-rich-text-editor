// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-rich-text-editor",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SwiftRichTextEditor",
            targets: ["SwiftRichTextEditor"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftRichTextEditor",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
        .testTarget(
            name: "SwiftRichTextEditorTests",
            dependencies: ["SwiftRichTextEditor"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),
    ]
)
