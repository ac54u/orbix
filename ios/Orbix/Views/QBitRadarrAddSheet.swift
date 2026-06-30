import SwiftUI

struct QBitRadarrAddSheet: View {
    let item: SearchResult
    let qualityProfiles: [RadarrApi.QualityProfile]
    let rootFolders: [RadarrApi.RootFolder]
    @State private var selectedQualityId = 0
    @State private var selectedRootPath = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        AsyncImage(url: URL(string: item.siteUrl)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                ZStack {
                                    AppColors.card
                                    Image(systemName: "film").foregroundColor(.gray.opacity(0.3))
                                }
                            }
                        }
                        .frame(width: 80, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                        Text(item.fileName)
                            .navTitle()
                            Text(String(format: OrbixStrings.labelTMDBID, item.num))
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.card)
                    )

                    VStack(spacing: 0) {
                        if qualityProfiles.isEmpty {
                            HStack {
                                Text(OrbixStrings.sectionQualityConfig).font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                ProgressView().controlSize(.mini)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        } else {
                            HStack {
                                Text(OrbixStrings.sectionQualityConfig).font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                Picker("", selection: $selectedQualityId) {
                                    ForEach(qualityProfiles) { p in
                                        Text(p.name).tag(p.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 2)
                        }

                        Divider().background(AppColors.separator)

                        if rootFolders.isEmpty {
                            HStack {
                                Text(OrbixStrings.sectionStoragePath).font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                ProgressView().controlSize(.mini)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        } else {
                            HStack {
                                Text(OrbixStrings.sectionStoragePath).font(.system(size: 14)).foregroundColor(AppColors.secondaryLabel)
                                Spacer()
                                Picker("", selection: $selectedRootPath) {
                                    ForEach(rootFolders) { f in
                                        Text(f.path).tag(f.path)
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 2)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.card)
                    )

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        confirmAdd()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text(OrbixStrings.btnAddAndSearch)
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.label)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.accent)
                        )
                    }
                    .padding(.top, 4)

                Text(OrbixStrings.infoRadarrHint)
                    .caption()
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(AppColors.mainBg)
            .navigationTitle(OrbixStrings.navAddToRadarr)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(OrbixStrings.btnCancel) { dismiss() }
                        .foregroundColor(AppColors.secondaryLabel)
                }
            }
            .onAppear {
                selectedQualityId = qualityProfiles.first?.id ?? 0
                selectedRootPath = rootFolders.first?.path ?? ""
            }
        }
    }

    private func confirmAdd() {
        let name = item.fileName
        let title: String
        let year: Int
        if let paren = name.lastIndex(of: "("), let close = name.lastIndex(of: ")"), paren < close {
            let yearStr = String(name[name.index(after: paren)..<close])
            title = String(name[..<paren]).trimmingCharacters(in: .whitespaces)
            year = Int(yearStr) ?? Calendar.current.component(.year, from: Date())
        } else {
            title = name
            year = Calendar.current.component(.year, from: Date())
        }
        Task {
            do {
                try await RadarrApi.addMovie(
                    tmdbId: item.num,
                    title: title,
                    year: year,
                    qualityProfileId: selectedQualityId,
                    rootFolderPath: selectedRootPath,
                    monitored: true,
                    searchOnAdd: true
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                await MainActor.run { dismiss() }
            } catch {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#if DEBUG
#Preview {
    QBitRadarrAddSheet(
        item: SearchResult(num: 12345, descr: "Test Movie", fileName: "Test.Movie.2024.1080p.mkv", fileSize: 2_147_483_648, nbLeechers: 5, nbSeeders: 100, siteUrl: "https://example.com/poster.jpg"),
        qualityProfiles: [
            RadarrApi.QualityProfile(id: 1, name: "HD - 1080p"),
            RadarrApi.QualityProfile(id: 2, name: "4K")
        ],
        rootFolders: [
            RadarrApi.RootFolder(id: 1, path: "/movies", freeSpace: nil),
            RadarrApi.RootFolder(id: 2, path: "/data/media", freeSpace: nil)
        ]
    )
}
#endif
