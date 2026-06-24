import SwiftUI

struct ServerSelectionView: View {
    let onConnected: () -> Void

    @State private var servers: [ServerConfig] = []
    @State private var isConnecting = false
    @State private var showLogin = false
    @State private var showManagement = false

    var body: some View {
        ZStack {
            AppColors.mainBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                GlowingLogo(size: 88)

                Text("选择服务器")
                    .largeTitle()

                if servers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)

                        Text("还没有添加服务器")
                            .subtitle()

                        Button {
                            showLogin = true
                        } label: {
                            Text("添加服务器")
                                .bodyFont(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(AppColors.accent)
                                )
                        }
                    }
                } else {
                    List(servers) { server in
                        Button {
                            connect(server)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(server.name)
                                        .bodyFont()
                                    Text(server.url)
                                        .subtitle()
                                }
                                Spacer()
                                Text(server.username)
                                    .caption()
                            }
                        }
                        .listRowBackground(AppColors.card)
                    }
                    .insetGroupedStyle()
                }

                Spacer()

                if !servers.isEmpty {
                    Button {
                        showManagement = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape")
                            Text("管理服务器")
                        }
                        .subtitle(AppColors.accent)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            loadServers()
        }
        .sheet(isPresented: $showLogin) {
            LoginView { config in
                servers.append(config)
                connect(config)
            }
        }
        .sheet(isPresented: $showManagement) {
            ServerManagementView(onSelected: { server in
                connect(server)
            })
        }
        .connectingDialog(isPresented: $isConnecting)
    }

    private func loadServers() {
        Task {
            let loaded = await QBitApi.shared.loadServers()
            await MainActor.run { servers = loaded }
        }
    }

    private func connect(_ server: ServerConfig) {
        isConnecting = true
        Task {
            await QBitApi.shared.setActiveServer(server)
            let result = await QBitApi.shared.connect()
            await MainActor.run {
                isConnecting = false
                if result.isSuccess {
                    onConnected()
                }
            }
        }
    }
}
