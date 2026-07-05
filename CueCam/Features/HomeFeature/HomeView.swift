import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "video.badge.waveform")
                .font(.system(size: 64))
                .foregroundStyle(AppColor.accent)

            Text("CueCam")
                .font(.largeTitle.bold())

            Text("何の動画を撮りますか？\nAIが撮影する場面を指示します")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("例: カフェの紹介動画", text: $store.theme)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)

            Button {
                store.send(.startButtonTapped)
            } label: {
                Label("撮影をはじめる", systemImage: "video.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
            .padding(.horizontal, 32)
            .disabled(store.theme.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
    }
}

#Preview {
    HomeView(
        store: Store(initialState: HomeFeature.State()) {
            HomeFeature()
        }
    )
}
