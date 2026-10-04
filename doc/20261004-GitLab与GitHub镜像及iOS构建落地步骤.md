# iOS Demo GitLab 与 GitHub 配置及构建步骤

## 1. 项目范围

本仓库只保存 iOS Demo，不处理原 `hqf-pay-app-sdk` 仓库中的 Android Demo、Android SDK 或 iOS SDK 源码。

本地项目路径：

~~~text
D:\project\xiaogun\tool\ocean-ios-demo
~~~

当前 Demo 文件包括：

- `OceanDemo.xcodeproj`：实际 iOS App 工程；
- `OceanDemoApp.swift`、`PaymentView.swift`：Demo 源码；
- `Info.plist`：App 配置；
- `Package.swift`：源码结构检查用的 Swift Package 文件；
- `README.md`：Demo 使用说明。

## 2. 当前远端配置

本地仓库配置了两个远端：

~~~text
github https://github.com/niuweixing2026/ocean-ios-demo.git
gitlab http://172.17.11.15:10900/tool/ocean-ios-demo
~~~

远端职责：

- `gitlab`：内部主仓库，用于团队协作和保存内部版本；
- `github`：公共镜像仓库，用于公开 Demo 和后续 GitHub Actions 构建。

当前 GitHub 仓库地址：

<https://github.com/niuweixing2026/ocean-ios-demo>

## 3. 当前分支和提交

当前本地分支为 `test`，已推送到两个远端：

~~~text
github/test
gitlab/test
~~~

当前首个 Demo 提交：

~~~text
18c3146 新增 iOS 支付 Demo
~~~

`main` 和 `test` 当前均为 Demo 初始版本。日常开发建议在 `test` 分支验证，确认后再合并或同步到 `main`。

## 4. 日常提交和推送

在项目目录执行：

~~~powershell
Set-Location D:\project\xiaogun\tool\ocean-ios-demo
git status --short
git add <变更文件>
git commit -m "中文提交说明"
~~~

推送到 GitLab：

~~~powershell
git push gitlab test
~~~

推送到 GitHub：

~~~powershell
git push github test
~~~

两个远端都需要同步时，依次执行：

~~~powershell
git push gitlab test
git push github test
~~~

当前仓库没有名为 `origin` 的远端，不要执行 `git push origin test`。如果需要查看远端名称和地址：

~~~powershell
git remote -v
~~~

## 5. 首次公开上传检查

GitHub 是公共仓库时，上传前检查 Demo 文件中是否包含密码、Token、证书或私钥：

~~~powershell
rg -n -I -i "(token|secret|password|private.?key|BEGIN RSA|BEGIN PRIVATE|\.p12|\.jks)" .
~~~

当前 Demo 不应提交以下文件：

- Apple 证书、`.p12`、Provisioning Profile；
- 私钥、Token、密码和测试账号；
- Xcode `DerivedData`、`xcuserdata`、SwiftPM 缓存；
- 本地构建产物和日志。

项目根目录的 `.gitignore` 已用于过滤 Xcode 和 SwiftPM 临时文件。

## 6. Apple App ID 说明

仅将 Demo 源码上传到 GitHub，不需要 Apple App ID、Apple Developer 账号、证书或 Provisioning Profile。

以下场景才需要 Apple Developer 配置：

- 真机安装和真机回归；
- 配置 Bundle ID、签名证书和 Provisioning Profile；
- Universal Link、URL Scheme、微信/支付宝回跳；
- TestFlight 或 App Store 发布。

## 7. iOS SDK 依赖现状

当前 `OceanDemo.xcodeproj` 使用本地 Swift Package 依赖：

~~~text
../ocean-ios-sdk
~~~

因此，本仓库可以独立公开 Demo 源码，但从 GitHub 单独克隆后暂时不能直接编译，原因是 GitHub 仓库中没有 `ocean-ios-sdk` 目录。

后续如果需要 GitHub 上的 Demo 可以直接编译，需要选择一种方式：

1. 将 `OceanPaySDK` 发布为可访问的远程 Swift Package，并把 Xcode 工程从本地依赖改为远程依赖；
2. 在本仓库中加入 `OceanPaySDK.xcframework` 并修改 Xcode 工程链接配置；
3. 只把本仓库作为 Demo 源码展示仓库，不承诺独立构建。

在 SDK 依赖方案确定前，不要添加会执行 `ocean-ios-sdk` 构建的 GitHub Actions 工作流，否则公共 Runner 会因找不到本地依赖而失败。

## 8. 后续 GitHub Actions 规划

当 SDK 依赖改为远程 Package 或 XCFramework 后，再在本仓库增加：

- `test` 分支：执行 Demo 编译检查；
- `main` 分支：执行主干编译检查；
- `v*` tag：执行版本构建或归档；
- `macos-14`：作为公共 macOS Runner；
- `xcodebuild`：执行 Xcode 工程构建；
- `actions/upload-artifact`：保存构建日志或测试产物。

真机归档、签名和发布流程必须等 Apple Developer 配置完成后再启用。

## 9. 常用检查命令

查看当前分支和提交：

~~~powershell
git status --short --branch
git branch -vv
git log --oneline --decorate -5
~~~

查看两个远端的分支：

~~~powershell
git ls-remote --heads github
git ls-remote --heads gitlab
~~~

确认工作区干净后再推送：

~~~powershell
git status --short
git push gitlab test
git push github test
~~~

## 10. 责任边界

~~~text
原 hqf-pay-app-sdk
├── Android Demo       不在本仓库处理
├── Android SDK        不在本仓库处理
└── iOS SDK 源码       不复制到本仓库

ocean-ios-demo
├── iOS Demo 工程      当前仓库内容
├── GitLab             内部主仓库
└── GitHub             公共 Demo 镜像
~~~

GitLab 和 GitHub 的代码应保持同一份 Demo 提交；GitLab 作为内部协作入口，GitHub 作为公共 Demo 和后续 macOS 构建入口。
