// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-rich-text-editor",
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
