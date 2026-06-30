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
            Form {
                Section {
                    VStack(spacing: 16) {
                        GlowingLogo(size: 64)

                        VStack(spacing: 6) {
                            Text("Orbix")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.label)
                            Text(OrbixStrings.infoConfigHint)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.secondaryLabel)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    FormRow(icon: "tag.fill", title: OrbixStrings.miscNameOptional) {
                        TextField(OrbixStrings.phServerName, text: $name)
                    }
                    FormRow(icon: "server.rack", title: OrbixStrings.miscHost) {
                        TextField(OrbixStrings.phHostAddress, text: $host)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                    }
                    FormRow(icon: "network", title: OrbixStrings.miscPort) {
                        TextField(OrbixStrings.phPort, text: $port)
                            .keyboardType(.numberPad)
                    }
                } header: {
                    Text(OrbixStrings.sectionServerInfo)
                }

                Section {
                    FormRow(icon: "person.fill", title: OrbixStrings.miscUsername) {
                        TextField(OrbixStrings.phUsername, text: $username)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    FormRow(icon: "lock.fill", title: OrbixStrings.miscPassword) {
                        HStack {
                            if showPassword {
                                TextField(OrbixStrings.phPassword, text: $password)
                            } else {
                                SecureField(OrbixStrings.phPassword, text: $password)
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(AppColors.secondaryLabel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text(OrbixStrings.sectionAuth)
                }

                Section {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(AppColors.secondaryLabel)
                            .frame(width: 28, alignment: .leading)
                        Toggle(OrbixStrings.miscEnableHTTPS, isOn: $https)
                            .tint(AppColors.accent)
                    }
                } footer: {
                    if https {
                        Text(OrbixStrings.infoSSLHint)
                    }
                }

                Section {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        testConnection()
                    } label: {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .tint(AppColors.accent)
                            } else {
                                Text(OrbixStrings.btnTestConnection)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isTesting || host.isEmpty)
                    if let result = testResult {
                        HStack {
                            Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.isSuccess ? AppColors.success : AppColors.danger)
                            Text(result.isSuccess ? OrbixStrings.miscConnectSuccess : result.message)
                                .font(.system(size: 13))
                                .foregroundColor(result.isSuccess ? AppColors.success : AppColors.danger)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text(OrbixStrings.infoTestHint)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg.ignoresSafeArea())
            .navigationTitle(server != nil ? OrbixStrings.navEditServer : OrbixStrings.navAddServer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(OrbixStrings.btnSave) { save() }
                        .font(.system(size: 15, weight: .bold))
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

#if DEBUG
#Preview {
    LoginView { _ in }
}
#endif

