import Foundation
import SwiftUI
import UIKit
import OceanPaySDK

private let payEndpoint = URL(string: "https://pay.360lingqian.com/gatewayTest")!
private let appCompURL = payEndpoint.appendingPathComponent("pri/V2/Pay/mock/appComp")
private let appPrepayURL = payEndpoint.appendingPathComponent("pri/V2/Pay/mock/appPrepayOrder")

struct DemoData: Codable {
    var compId = ""
    var compName = ""
    var prodId = ""
    var prodName = ""
    var body = ""
    var money = ""
    var coin: [String] = []
    var country: [String] = []

    enum CodingKeys: String, CodingKey {
        case compId, compName, prodId, prodName, body, money, coin, country
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        compId = try container.decodeIfPresent(String.self, forKey: .compId) ?? ""
        compName = try container.decodeIfPresent(String.self, forKey: .compName) ?? ""
        prodId = try container.decodeIfPresent(String.self, forKey: .prodId) ?? ""
        prodName = try container.decodeIfPresent(String.self, forKey: .prodName) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        money = try container.decodeIfPresent(String.self, forKey: .money) ?? ""
        coin = Self.decodeStringArray(container, key: .coin)
        country = Self.decodeStringArray(container, key: .country)
    }

    private static func decodeStringArray(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> [String] {
        if let values = try? container.decode([String].self, forKey: key) { return values }
        guard let raw = try? container.decode(String.self, forKey: key),
              let data = raw.data(using: .utf8) else { return [] }
        if let values = try? JSONDecoder().decode([String].self, from: data) { return values }
        return raw.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }.filter { !$0.isEmpty }
    }
}

struct DemoPaymentResult: Identifiable {
    let id = UUID()
    let result: OceanPaymentResult
}

enum DemoRequestError: LocalizedError {
    case invalid(String)
    case response(String)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .response(message): return message
        }
    }
}

@MainActor
final class PaymentViewModel: ObservableObject {
    @Published var data = DemoData()
    @Published var amount = "1"
    @Published var currency = "USD"
    @Published var message = "正在加载商户数据..."
    @Published var isLoading = false
    @Published var paymentResult: DemoPaymentResult?
    weak var presenter: UIViewController?
    private var sdkConfigured = false

    func load() {
        isLoading = true
        message = "正在加载商户数据..."
        post(url: appCompURL, body: [:]) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                do {
                    let payload = try result.get()
                    self.data = try JSONDecoder().decode(DemoData.self, from: payload)
                    self.amount = self.data.money.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1" : self.data.money
                    self.currency = self.data.coin.first?.uppercased() ?? "USD"
                    self.message = "商户数据加载完成"
                } catch {
                    self.message = "加载失败：\(error.localizedDescription)，请重试"
                }
            }
        }
    }

    func pay() {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCoin = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !data.compId.isEmpty, !data.prodId.isEmpty else {
            message = "商户数据尚未加载完成"
            return
        }
        guard Decimal(string: trimmedAmount).map({ $0 > 0 }) == true else {
            message = "金额必须是大于0的数字"
            return
        }
        guard !trimmedCoin.isEmpty, data.body.count >= 2 else {
            message = "币种和订单说明不能为空"
            return
        }
        guard let presenter else {
            message = "未找到支付页面容器，请重试"
            return
        }
        isLoading = true
        message = "正在创建预支付订单..."
        let body: [String: Any] = [
            "compId": data.compId,
            "prodId": data.prodId,
            "money": trimmedAmount,
            "coin": trimmedCoin,
            "remark": data.body,
            "sourceType": "IOS",
            "osType": "IOS",
            "iosReturnUrl": "https://www.heqipay.com"
        ]
        post(url: appPrepayURL, body: body) { [weak self, presenter] result in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false
                do {
                    let orderPackage = try result.get()
                    if !self.sdkConfigured {
                        try OceanPaySDK.shared.configure(OceanPayOptions(endpoint: payEndpoint))
                        self.sdkConfigured = true
                    }
                    try OceanPaySDK.shared.present(orderPackage: orderPackage, from: presenter) { [weak self] result in
                        Task { @MainActor in
                            self?.paymentResult = DemoPaymentResult(result: result)
                        }
                    }
                    self.message = "预支付订单创建完成"
                } catch {
                    self.message = "预下单失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func post(url: URL, body: [String: Any], completion: @escaping (Result<Data, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data, let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                completion(.failure(DemoRequestError.response("服务端响应异常")))
                return
            }
            do {
                guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw DemoRequestError.response("服务端返回格式错误")
                }
                if let code = root["code"], String(describing: code) != "0000" {
                    throw DemoRequestError.response(root["msg"] as? String ?? "服务端请求失败")
                }
                let payload = root["retContent"] ?? root["data"] ?? root
                if let object = payload as? [String: Any] {
                    completion(.success(try JSONSerialization.data(withJSONObject: object)))
                } else if let text = payload as? String, let payloadData = text.data(using: .utf8) {
                    completion(.success(payloadData))
                } else {
                    throw DemoRequestError.response("服务端返回订单包格式错误")
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

struct PaymentView: View {
    @StateObject private var model = PaymentViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("境外支付测试Demo")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color(red: 0.08, green: 0.18, blue: 0.32))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    DemoCard(title: "订单信息") {
                        readOnly("商户", displayValue(model.data.compId, model.data.compName))
                        readOnly("产品", displayValue(model.data.prodId, model.data.prodName))
                        readOnly("商品名称/订单说明", model.data.body)
                    }

                    DemoCard(title: "支付参数") {
                        TextField("金额", text: $model.amount)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                        TextField("币种", text: $model.currency)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                        Text("可用币种：\(model.data.coin.map { $0.uppercased() }.joined(separator: "、").ifEmpty("未返回"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("国家/地区：\(model.data.country.map { $0.uppercased() }.joined(separator: "、").ifEmpty("未返回"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        Button {
                            model.pay()
                        } label: {
                            Text("立即支付")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.isLoading)

                        Button("重新加载") { model.load() }
                            .frame(maxWidth: .infinity)
                            .disabled(model.isLoading)
                    }

                    Text(model.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(red: 0.96, green: 0.97, blue: 0.98).ignoresSafeArea())
            .navigationTitle("支付 Demo")
            .navigationDestination(item: $model.paymentResult) { value in
                ResultView(result: value.result)
            }
            .background(ViewControllerResolver { model.presenter = $0 }.frame(width: 0, height: 0))
            .task { model.load() }
        }
    }

    private func readOnly(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.isEmpty ? "加载中" : value).foregroundStyle(.secondary)
        }
    }

    private func displayValue(_ id: String, _ name: String) -> String {
        [id, name].filter { !$0.isEmpty }.joined(separator: " / ")
    }
}

private struct DemoCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(red: 0.08, green: 0.18, blue: 0.32))
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

struct ResultView: View {
    let result: OceanPaymentResult

    private var isSuccess: Bool {
        ["success", "succeed", "paid", "pay_success"].contains(result.statusCode.lowercased())
    }

    private var isFailure: Bool {
        let code = result.statusCode.lowercased()
        return code.contains("fail") || code.contains("error") || code == "cancel"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(isSuccess ? .green : .orange)
            Text(isSuccess ? "支付成功" : (isFailure ? "支付失败" : "支付处理中"))
                .font(.largeTitle.bold())
            Text("订单号：\(result.cashNum)")
            Text("状态：\(result.statusCode)")
            if let statusMsg = result.statusMsg, !statusMsg.isEmpty { Text(statusMsg) }
        }
        .padding()
        .navigationTitle("支付结果")
    }
}

private struct ViewControllerResolver: UIViewControllerRepresentable {
    let onResolve: (UIViewController) -> Void

    func makeUIViewController(context: Context) -> ResolverViewController {
        ResolverViewController(onResolve: onResolve)
    }

    func updateUIViewController(_ uiViewController: ResolverViewController, context: Context) {}
}

private final class ResolverViewController: UIViewController {
    private let onResolve: (UIViewController) -> Void

    init(onResolve: @escaping (UIViewController) -> Void) {
        self.onResolve = onResolve
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onResolve(parent ?? self)
    }
}
