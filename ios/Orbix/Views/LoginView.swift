import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    let server: ServerConfig?
    let onSave: (ServerConfig) -> Void

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "8080"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var https: Bool = false
    @State private var showPassword: Bool = false

    @State private var isTesting = false
    @State private var testResult: ConnectResult?

    init(server: ServerConfig? = nil, onSave: @escaping (ServerConfig) -> Void) {
        self.server = server
        self.onSave = onSave
        _name = State(initialValue: server?.name ?? "")
        _host = State(initialValue: server?.host ?? "")
        _port = State(initialValue: "\(server?.port ?? 8080)")
        _username = State(initialValue: server?.username ?? "")
        _password = State(initialValue: server?.password ?? "")
        _https = State(initialValue: server?.https ?? false)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        GlowingLogo(size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Orbix")
                                .navTitle()
                            Text("配置 qBittorrent 连接")
                                .caption()
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("服务器信息") {
                    TextField("名称（可选）", text: $name)
                        .bodyFont()
                    TextField("主机地址", text: $host)
                        .bodyFont()
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    TextField("端口", text: $port)
                        .bodyFont()
                        .keyboardType(.numberPad)
                }

                Section("认证") {
                    TextField("用户名", text: $username)
                        .bodyFont()
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    HStack {
                        if showPassword {
                            TextField("密码", text: $password)
                                .bodyFont()
                        } else {
                            SecureField("密码", text: $password)
                                .bodyFont()
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $https) {
                        Text("HTTPS")
                            .bodyFont()
                    }
                    .tint(AppColors.accent)
                } footer: {
                    if https {
                        Text("确保你的 qBittorrent 已配置 SSL 证书")
                            .caption()
                    }
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("测试连接")
                                .bodyFont()
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .tint(AppColors.accent)
                            } else if let result = testResult {
                                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.isSuccess ? AppColors.success : AppColors.danger)
                            }
                        }
                    }
                    .disabled(isTesting || host.isEmpty)

                    if let result = testResult, !result.isSuccess {
                        Text(result.message)
                            .caption(AppColors.danger)
                    }
                } footer: {
                    Text("测试将尝试使用当前配置连接到 qBittorrent")
                        .caption()
                }
            }
            .insetGroupedStyle()
            .navigationTitle(server != nil ? "编辑服务器" : "添加服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(host.isEmpty || username.isEmpty)
                }
            }
        }
    }

    private func testConnection() {
        let config = buildConfig()
        isTesting = true
        testResult = nil

        Task {
            await QBitApi.shared.setActiveServer(config)
            let result = await QBitApi.shared.connect()
            await MainActor.run {
                isTesting = false
                testResult = result
            }
        }
    }

    private func save() {
        let config = buildConfig()
        Task { await QBitApi.shared.upsertServer(config) }
        onSave(config)
        dismiss()
    }

    private func buildConfig() -> ServerConfig {
        ServerConfig(
            name: name.isEmpty ? host : name,
            host: host,
            port: Int(port) ?? 8080,
            username: username,
            password: password,
            https: https
        )
    }
}
