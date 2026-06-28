import SwiftUI

struct AddServiceView: View {
    @Environment(\.dismiss) private var dismiss

    let existing: ServiceCredential?
    let onSave: (ServiceCredential) -> Void

    @State private var kind: ServiceKind
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var apiKey: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var https: Bool = false
    @State private var showApiKey: Bool = false
    @State private var showPassword: Bool = false
    @State private var isTesting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(existing: ServiceCredential? = nil, onSave: @escaping (ServiceCredential) -> Void) {
        self.existing = existing
        self.onSave = onSave
        let cred = existing
        _kind = State(initialValue: cred?.kind ?? .qBittorrent)
        _name = State(initialValue: cred?.name ?? "")
        _host = State(initialValue: cred?.host ?? "")
        _port = State(initialValue: cred != nil ? "\(cred!.port)" : "")
        _apiKey = State(initialValue: cred?.apiKey ?? "")
        _username = State(initialValue: cred?.username ?? "")
        _password = State(initialValue: cred?.password ?? "")
        _https = State(initialValue: cred?.https ?? false)
    }

    private var defaultPort: String {
        switch kind {
        case .qBittorrent: return "8080"
        case .prowlarr: return "9696"
        case .radarr: return "7878"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("服务类型", selection: $kind) {
                        ForEach(ServiceKind.allCases, id: \.self) { k in
                            HStack(spacing: 6) {
                                Image(systemName: k.icon)
                                Text(k.rawValue)
                            }
                            .tag(k)
                        }
                    }
                    .onChange(of: kind) { _, _ in
                        if port.isEmpty { port = defaultPort }
                    }
                }

                Section {
                    HStack {
                        Text("名称").foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("可选", text: $name)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                    }

                    HStack {
                        Text("主机").foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("192.168.1.100", text: $host)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .foregroundColor(AppColors.label)
                    }

                    HStack {
                        Text("端口").foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField(defaultPort, text: $port)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .foregroundColor(AppColors.label)
                    }

                    Toggle(isOn: $https) {
                        Text("HTTPS").foregroundColor(AppColors.secondaryLabel)
                    }
                    .tint(AppColors.accent)
                } header: {
                    Text("连接")
                }

                if kind == .qBittorrent {
                    Section {
                        HStack {
                            Text("用户名").foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            TextField("admin", text: $username)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .foregroundColor(AppColors.label)
                        }
                        HStack {
                            Text("密码").foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            Group {
                                if showPassword {
                                    TextField("", text: $password)
                                } else {
                                    SecureField("", text: $password)
                                }
                            }
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.caption)
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                        }
                    } header: {
                        Text("认证")
                    }
                } else {
                    Section {
                        HStack {
                            Text("API Key").foregroundColor(AppColors.secondaryLabel)
                            Spacer()
                            Group {
                                if showApiKey {
                                    TextField("", text: $apiKey)
                                } else {
                                    SecureField("", text: $apiKey)
                                }
                            }
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                            Button {
                                showApiKey.toggle()
                            } label: {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    .font(.caption)
                                    .foregroundColor(AppColors.tertiaryLabel)
                            }
                        }
                    } header: {
                        Text("认证")
                    } footer: {
                        Text("在 \(kind.rawValue) 设置 → General 中找到 API Key")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(AppColors.mainBg)
            .navigationTitle(existing != nil ? "编辑服务" : "添加服务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColors.secondaryLabel)
                        .disabled(isTesting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isTesting {
                        ProgressView().tint(AppColors.accent)
                    } else {
                        Button("连接") { Task { await testAndSave() } }
                            .fontWeight(.bold)
                            .foregroundColor(host.isEmpty ? AppColors.secondaryLabel : AppColors.accent)
                            .disabled(host.isEmpty)
                    }
                }
            }
            .alert("连接测试", isPresented: $showAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func testAndSave() async {
        guard !host.isEmpty else { return }
        let portValue = Int(port) ?? (https ? 443 : 80)
        isTesting = true

        let result = await CredentialsManager.testConnection(
            kind: kind, host: host, port: portValue, https: https,
            apiKey: apiKey, username: username, password: password
        )

        if result.isSuccess {
            isTesting = false
            saveCredential(port: portValue)
            await MainActor.run { dismiss() }
        } else {
            await MainActor.run {
                isTesting = false
                alertMessage = result.message
                showAlert = true
            }
        }
    }

    private func saveCredential(port portValue: Int) {
        let cleanHost = host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        var cred = ServiceCredential(
            kind: kind, name: name.isEmpty ? kind.rawValue : name,
            host: cleanHost, port: portValue, https: https,
            apiKey: apiKey, username: username, password: password
        )
        if let existing = existing {
            cred = ServiceCredential(
                kind: kind, name: name.isEmpty ? existing.name : name,
                host: cleanHost, port: portValue, https: https,
                apiKey: apiKey.isEmpty ? existing.apiKey : apiKey,
                username: username, password: password
            )
        }
        onSave(cred)
                }
            }
