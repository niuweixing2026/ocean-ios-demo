# 境外支付测试Demo iOS

原生 SwiftUI 测试页面，建议最低 iOS 16。启动后请求 `POST https://****/gatewayTest/pri/V2/Pay/mock/appComp`，展示商户、产品、商品信息以及后台返回的金额、可用币种和国家/地区；金额和币种默认取接口返回值。点击“立即支付”会先请求 `appPrepayOrder` 获取订单包，再交给 `OceanPaySDK` 拉起支付，最终结果以 SDK 回调为准。

直接用 Xcode 打开 `OceanDemo.xcodeproj` 即可运行。工程已配置本地 Swift Package `../ocean-ios-sdk`，`Package.swift` 仅用于源码结构检查，不能替代 iOS App Target。
