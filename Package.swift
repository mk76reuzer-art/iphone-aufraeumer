// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AufraeumerKern",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "AufraeumerKern", targets: ["AufraeumerKern"])
    ],
    targets: [
        .target(name: "AufraeumerKern"),
        .testTarget(name: "AufraeumerKernTests", dependencies: ["AufraeumerKern"])
    ]
)
