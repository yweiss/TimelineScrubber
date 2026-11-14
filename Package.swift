// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimelineScrubber",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "TimelineScrubber", targets: ["TimelineScrubber"])],
    targets: [.target(name: "TimelineScrubber"), .testTarget(name: "TimelineScrubberTests", dependencies: ["TimelineScrubber"])]
)
