import SwiftUI

struct TorrentCard: View {
    let torrent: ScrapedTorrent
    @State private var loadedImage: UIImage?

    private var thumbnailURL: URL? {
        guard let url = torrent.thumbnail else { return nil }
        return URL(string: url)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            } else {
                ZStack {
                    AppColors.card
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.placeholder)
                }
            }

            if !torrent.size.isEmpty {
                Text(torrent.size)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: AppRadius.xs).fill(.black.opacity(0.65)))
                    .padding([.bottom, .trailing], 4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .task(id: torrent.id) {
            guard let url = thumbnailURL else {
                loadedImage = nil
                return
            }
            if let cached = ImageCache.shared.get(url.absoluteString) {
                loadedImage = cached
                return
            }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let img = UIImage(data: data) {
                    ImageCache.shared.set(url.absoluteString, image: img)
                    loadedImage = img
                }
            } catch {
#if DEBUG
                print("[TorrentCard] image load error: \(error)")
#endif
            }
        }
    }
}

#if DEBUG
#Preview {
    TorrentCard(torrent: .demo())
        .frame(width: 160, height: 160)
}
#endif
