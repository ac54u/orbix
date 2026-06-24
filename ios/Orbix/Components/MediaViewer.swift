import SwiftUI

struct MediaViewer: View {
    let images: [String]
    let initialIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex: Int

    init(images: [String], initialIndex: Int = 0) {
        self.images = images
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { index in
                    ImagePage(url: images[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    if images.count > 1 {
                        Text("\(currentIndex + 1) / \(images.count)")
                            .bodyFont(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }
        }
        .interactiveDismissDisabled()
    }
}

private struct ImagePage: View {
    let url: String

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero

    var body: some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, value)
                            }
                            .onEnded { _ in
                                withAnimation(.spring()) {
                                    scale = 1
                                    offset = .zero
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard scale <= 1 else { return }
                                offset = value.translation
                            }
                            .onEnded { value in
                                if abs(value.translation.height) > 150 {
//                                    dismiss()
                                } else {
                                    withAnimation(.spring()) {
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            scale = scale == 1 ? 2.5 : 1
                        }
                    }
            case .failure:
                VStack {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.5))
                }
            case .empty:
                ProgressView()
                    .tint(.white)
            @unknown default:
                EmptyView()
            }
        }
    }
}
