// 便于在没有完整 Xcode 工程模板时检查 Swift 源码结构；实际 iOS App 请用 Xcode 创建 iOS App Target 并加入本目录源码。
import PackageDescription

let package = Package(name: "OceanDemoSources", platforms: [.iOS(.v16)], targets: [.target(name: "OceanDemoSources", path: ".", exclude: ["README.md", "Info.plist"])])
