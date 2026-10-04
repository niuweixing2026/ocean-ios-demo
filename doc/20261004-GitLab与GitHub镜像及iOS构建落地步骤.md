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

## 6. GitHub 远程打包与本机安装

目标流程是：

~~~text
GitHub test 分支
        ↓
GitHub Actions macOS Runner 远程构建
        ↓
在 macOS Runner 上启动 iOS Simulator 并运行
        ↓
上传日志、截图或视频
        ↓
Windows 下载 Actions Artifact 查看结果
~~~

这里要区分两个概念：

- **Apple ID**：登录 Apple Developer 和管理签名资源的账号；
- **Apple App ID**：Apple Developer 中的 App 标识，通常由 Team ID 和 Bundle ID 组成；当前工程的 Bundle ID 是 `com.zxfd.oceandemo`。

### 6.1 远程构建模拟器包

GitHub Actions 可以在 `macos-14` Runner 上构建并运行 iOS Simulator。Windows 本机不能安装 Apple 的 iOS Simulator，因为 Simulator 依赖 macOS 和 Xcode。这个流程不需要 Apple ID、证书或 Provisioning Profile，也不涉及真机签名。

典型构建命令：

~~~bash
xcodebuild \
  -project OceanDemo.xcodeproj \
  -scheme OceanDemo \
  -destination "generic/platform=iOS Simulator" \
  -configuration Debug \
  build
~~~

下面的命令应在 GitHub Actions 的 macOS Runner 上执行，而不是 Windows 本机：

~~~bash
xcrun simctl list devices available
xcrun simctl boot "iPhone 16"
xcrun simctl install booted OceanDemo.app
xcrun simctl launch booted com.zxfd.oceandemo
xcrun simctl io booted screenshot simulator.png
~~~

然后使用 `actions/upload-artifact` 上传 `simulator.png`、构建日志和其他测试结果，Windows 只负责从 GitHub Actions 下载并查看这些文件。

### 6.2 远程构建真机安装包

如果目标是“GitHub 远程打包后安装到本机 iPhone/iPad”，Actions 必须生成已签名的 `.ipa` 或已签名 `.app`。未签名的 `iphoneos` 构建产物不能直接安装到真机。

真机远程打包需要准备：

1. Apple ID，并加入 Apple Developer Program；
2. App ID/Bundle ID：`com.zxfd.oceandemo`；
3. Distribution 或 Development 证书；
4. 与设备 UDID 匹配的 Provisioning Profile；
5. 将证书和 Profile 以 GitHub Actions Secrets 形式保存。

推荐的 Actions Secrets 名称：

~~~text
BUILD_CERTIFICATE_BASE64
P12_PASSWORD
PROVISIONING_PROFILE_BASE64
KEYCHAIN_PASSWORD
TEAM_ID
~~~

证书、`.p12`、Provisioning Profile 和密码不能提交到 Git 仓库。Actions 中完成签名后，再使用 `xcodebuild -exportArchive` 导出 `.ipa` 并上传为 Artifact。

### 6.3 Windows 本机能做什么

当前不考虑真机时，Windows 本机不能安装或运行 iOS Simulator，也不能使用 `xcrun`、`simctl` 或 Xcode。Windows 本机可以执行以下工作：

1. 推送 `test` 分支，触发 GitHub Actions；
2. 下载 Actions 上传的构建日志、Simulator 截图、视频和测试报告；
3. 查看 Actions 的成功或失败状态；
4. 通过远程 Mac、云 Mac 或团队成员的 Mac 进行交互式模拟器操作。

如果确实需要在本机看到模拟器界面，必须使用 macOS 设备登录 GitHub 或远程桌面；Windows 没有官方受支持的 iOS Simulator 安装方式。

### 6.4 当前没有 Apple ID 时的结论

- 通过 GitHub Actions 在 macOS Runner 上构建、启动 Simulator 和上传截图：现在可以进行，不需要 Apple ID；
- 在 Windows 本机安装 iOS Simulator：不支持，不能通过安装普通软件解决；
- 下载 `.app` 到 Windows：只能保存或查看文件，不能在 Windows 上运行；
- 后续如果改为实体 iPhone/iPad 安装，再准备 Apple ID、Apple Developer Program、证书和 Provisioning Profile。

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

## 8. 第一次使用 GitHub Actions 的完整操作

当前目标是：Windows 提交代码，GitHub Actions 使用 macOS Runner 构建并运行 iOS Simulator，Windows 下载截图、日志和测试结果。Windows 不安装 iOS Simulator。

### 8.1 第一步：先解决 SDK 依赖

当前 `OceanDemo.xcodeproj` 使用本地依赖：

~~~text
../ocean-ios-sdk
~~~

GitHub Actions 只会检出 `ocean-ios-demo`，不会自动拥有同级的 `ocean-ios-sdk` 目录。因此，直接创建 Workflow 会在 Xcode 构建阶段失败。

先选择一种依赖方案：

1. 将 `OceanPaySDK` 发布成远程 Swift Package，把 Xcode 工程的本地依赖改成 GitHub/GitLab Package URL；
2. 将 `OceanPaySDK.xcframework` 放入 Demo 仓库并在 Xcode 工程中配置链接；
3. 仅做源码展示，不执行 Xcode 构建。

只有完成第 1 或第 2 种方案后，才继续执行本节的构建步骤。

### 8.2 第二步：检查 GitHub 仓库和分支

在 Windows 浏览器打开：

<https://github.com/niuweixing2026/ocean-ios-demo>

依次检查：

1. 点击 `Code`，确认能看到 `OceanDemo.xcodeproj`、Swift 源码和 `doc` 目录；
2. 点击分支下拉框，确认存在 `main` 和 `test`；
3. 切换到 `test`，确认最新提交是准备构建的版本；
4. 点击 `Settings` → `Actions` → `General`；
5. 确认 `Actions permissions` 允许使用 Actions；
6. 在 `Workflow permissions` 中选择默认的只读权限即可，本次构建不需要写仓库；
7. 点击 `Save` 保存设置。

如果仓库是由 GitLab 镜像到 GitHub，必须确认包含 `.github/workflows/*.yml` 的提交已经同步到 GitHub；只有 GitLab 本地有文件，GitHub Actions 不会看到它。

### 8.3 第三步：创建 Workflow 文件

在本地项目创建文件：

~~~text
.github/workflows/ios-demo-simulator.yml
~~~

文件内容示例：

~~~yaml
name: iOS Demo Simulator

on:
  push:
    branches:
      - test
  workflow_dispatch:

jobs:
  build-and-simulate:
    runs-on: macos-14
    timeout-minutes: 30

    steps:
      - name: 检出代码
        uses: actions/checkout@v4

      - name: 查看 Xcode 版本
        run: xcodebuild -version

      - name: 查看工程 Scheme
        run: xcodebuild -project OceanDemo.xcodeproj -list

      - name: 构建 iOS Simulator App
        run: >-
          xcodebuild
          -project OceanDemo.xcodeproj
          -scheme OceanDemo
          -destination "generic/platform=iOS Simulator"
          -configuration Debug
          -derivedDataPath build/DerivedData
          build

      - name: 启动模拟器并运行 Demo
        run: |
          DEVICE_ID=$(xcrun simctl list devices available | grep -m 1 -E 'iPhone.*\(.*\)' | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/')
          test -n "$DEVICE_ID"
          xcrun simctl boot "$DEVICE_ID" || true
          xcrun simctl bootstatus "$DEVICE_ID" -b
          xcrun simctl install "$DEVICE_ID" build/DerivedData/Build/Products/Debug-iphonesimulator/OceanDemo.app
          xcrun simctl launch "$DEVICE_ID" com.zxfd.oceandemo
          xcrun simctl io "$DEVICE_ID" screenshot build/simulator.png

      - name: 上传构建结果
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ios-demo-simulator-result
          path: |
            build/DerivedData/Build/Products/Debug-iphonesimulator/OceanDemo.app
            build/simulator.png
          if-no-files-found: warn
~~~

说明：

- `push.branches.test`：向 `test` 推送时自动触发；
- `workflow_dispatch`：允许在 GitHub 页面手动点击运行；
- `macos-14`：GitHub 提供的 macOS Runner，负责运行 Xcode 和 iOS Simulator；
- `derivedDataPath`：把构建产物固定到 `build/DerivedData`，便于上传；
- `if: always()`：即使构建失败，也尽量上传已有日志或截图；
- 该 Workflow 只构建 Simulator，不需要 Apple ID、证书或 Provisioning Profile。

### 8.4 第四步：提交并推送 Workflow

在 Windows PowerShell 执行：

~~~powershell
Set-Location D:\project\xiaogun\tool\ocean-ios-demo
git switch test
git status --short
git add .github/workflows/ios-demo-simulator.yml
git commit -m "新增 iOS Demo 模拟器构建工作流"
git push gitlab test
git push github test
~~~

推荐先推送 GitLab，再推送 GitHub。推送后在 GitHub 的 `Code` 页面切换到 `test`，确认能看到 `.github/workflows/ios-demo-simulator.yml`。

如果 GitHub 推送网络超时，不要重复创建提交；确认本地提交已经存在，网络恢复后只需再次执行：

~~~powershell
git push github test
~~~

### 8.5 第五步：在 GitHub 页面手动运行

首次运行建议手动触发，操作如下：

1. 打开 GitHub 仓库，点击顶部 `Actions`；
2. 左侧选择 `iOS Demo Simulator`；
3. 点击右侧 `Run workflow`；
4. Branch 选择 `test`；
5. 点击绿色的 `Run workflow`；
6. 等待任务进入 `In progress`，点击进入查看每个 Step 的日志；
7. 看到绿色 `build-and-simulate` 表示成功；
8. 如果失败，展开第一个红色 Step，复制错误日志定位问题。

### 8.6 第六步：下载构建结果到 Windows

任务成功后：

1. 在该次 Workflow 运行页面底部找到 `Artifacts`；
2. 点击 `ios-demo-simulator-result` 下载 ZIP；
3. 在 Windows 解压 ZIP；
4. 查看 `simulator.png`；
5. 查看 `OceanDemo.app` 是否存在；
6. 查看构建日志确认使用的 Xcode 和目标设备版本。

Windows 可以保存和查看这些文件，但不能直接运行 `OceanDemo.app`，也不能启动 iOS Simulator。

### 8.7 第七步：确认自动触发

手动运行成功后，在 Windows 修改 Demo 文件并提交到 `test`：

~~~powershell
git add <变更文件>
git commit -m "更新 iOS Demo"
git push gitlab test
git push github test
~~~

每次 GitHub 收到 `test` 分支的新提交后，`push` 规则会自动触发 Workflow。可以在 `Actions` 页面查看新的运行记录。

### 8.8 常见失败和处理方法

| 现象 | 原因 | 处理方式 |
| --- | --- | --- |
| Actions 页面没有 Workflow | `.yml` 没推到 GitHub，或 Actions 被禁用 | 检查 `test` 分支文件和 `Settings → Actions` |
| `xcodebuild -list` 失败 | 工程文件或 Scheme 名称不对 | 查看日志，确认 Scheme 是否为 `OceanDemo` |
| 找不到 `ocean-ios-sdk` | 工程仍引用本地 `../ocean-ios-sdk` | 改远程 Package 或加入 XCFramework |
| 找不到 `OceanDemo.app` | 构建失败或产物路径不同 | 查看构建 Step，必要时执行 `find build -name OceanDemo.app` |
| `simctl install` 失败 | App 没有生成或目标不是 Simulator | 确认使用 `generic/platform=iOS Simulator` |
| Workflow 排队很久 | 公共 macOS Runner 排队或配额限制 | 等待 Runner，查看 Actions 运行详情 |
| Windows 无法打开 `.app` | `.app` 是 macOS/iOS 产物 | 只能下载查看，运行必须在 macOS Runner 或 Mac 上 |

### 8.9 后续分支规则

1. `test`：首次构建和日常 Demo 验证；
2. `main`：确认通过后的主干构建；
3. `v*` tag：后续版本构建；
4. 当前不配置 `iphoneos`、证书、Profile 和 `.ipa`，因为暂时不考虑真机。

远程 Runner 使用 `macos-14`，构建使用 `xcodebuild`，模拟器使用 `xcrun simctl`，截图和日志使用 `actions/upload-artifact` 保存。

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
