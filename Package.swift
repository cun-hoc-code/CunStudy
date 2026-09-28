// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StudyCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "StudyCore", targets: ["StudyCore"])],
    dependencies: [.package(url: "https://github.com/weichsel/ZIPFoundation.git", exact: "0.9.20")],
    targets: [
        .systemLibrary(name: "CSQLite", path: "System/CSQLite"),
        .target(name: "StudyCore", dependencies: ["ZIPFoundation", "CSQLite"], path: ".", exclude: ["App", "FocusMonitor", "MamStudy.xcodeproj", "Widget", "Shared", "Resources", "Config", "Tests", "docs", "Examples", "Verification", "scripts", "System", "README.md", "HUONG-DAN.md", "CHANGELOG.md", "project.yml"], sources: ["Core", "Storage"]),
        .testTarget(name: "StudyCoreTests", dependencies: ["StudyCore"], path: "Tests")
    ]
)
