// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	 name: "Convey",
	  platforms: [
				  .macOS(.v10_15),
				  .iOS(.v14),
				  .watchOS(.v7)
			],
	 products: [
		  // Products define the executables and libraries produced by a package, and make them visible to other packages.
		  .library(
				name: "Convey",
				targets: ["Convey"]),
	 ],
	 dependencies: [
	 ],
	 targets: [
		  // Targets are the basic building blocks of a package. A target can define a module or a test suite.
		  // Targets can depend on other targets in this package, and on products in packages which this package depends on.
		  .target(name: "Convey", dependencies: ["system-zlib"]),
		  .target(name: "system-zlib"),
		  .testTarget(name: "ConveyTests", dependencies: ["Convey"], resources: [.copy("test_assets.xcassets")]),
	 ]
)
