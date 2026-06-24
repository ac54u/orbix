import SwiftUI

struct ServerManagementView: View {
    let onSelected: (ServerConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var servers: [ServerConfig] = []
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.groupedBg.ignoresSafeArea()

                if servers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.placeholder)

                        Text("暂无服务器")
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
                    List {
                        ForEach(servers) { server in
                            ServerRow(server: server)
                                .onTapGesture {
                                    onSelected(server)
                                    dismiss()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        delete(server)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }

                                    Button {
                                        showLoginWith(server)
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    .tint(AppColors.accent)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        onSelected(server)
                                        dismiss()
                                    } label: {
                                        Label("连接", systemImage: "link")
                                    }
                                    .tint(AppColors.success)
                                }
                                .listRowBackground(AppColors.card)
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                Task { await QBitApi.shared.removeServer(servers[idx]) }
                            }
                            servers.remove(atOffsets: indexSet)
                        }
                    }
                    .insetGroupedStyle()
                }
            }
            .navigationTitle("服务器管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLoginWith(nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear { loadServers() }
        .sheet(isPresented: $showLogin) {
            // editingServer passed via environment hack
        }
    }

    private func loadServers() {
        Task {
            let loaded = await QBitApi.shared.loadServers()
            await MainActor.run { servers = loaded }
        }
    }

    private func delete(_ server: ServerConfig) {
        Task { await QBitApi.shared.removeServer(server) }
        servers.removeAll { $0 == server }
    }

    private func showLoginWith(_ server: ServerConfig?) {
        // This would ideally pass server to LoginView via state
    }
}

private struct ServerRow: View {
    let server: ServerConfig

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .bodyFont()
                    Image(systemName: server.https ? "lock.fill" : "lock.open")
                        .font(.caption2)
                        .foregroundColor(server.https ? AppColors.success : AppColors.secondaryLabel)
                }
                Text(server.url)
                    .subtitle()
                Text(server.username)
                    .caption()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.tertiaryLabel)
        }
        .padding(.vertical, 4)
    }
}
