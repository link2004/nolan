import ComposableArchitecture
import SwiftUI

struct ShootView: View {
    let store: StoreOf<ShootFeature>

    var body: some View {
        ZStack {
            // TODO: CameraClient実装後、AVCaptureVideoPreviewLayerのプレビューに差し替える
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                header

                Spacer()

                if store.isLoadingPlan {
                    ProgressView("AIが撮影プランを考えています…")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if let error = store.loadError {
                    Text(error)
                        .foregroundStyle(.red)
                } else if let shot = store.currentShot {
                    instructionCard(shot)
                }

                controls
            }
            .padding()
        }
        .onAppear { store.send(.onAppear) }
    }

    private var header: some View {
        HStack {
            Text("\(store.currentShotIndex + 1) / \(store.shotPlan.count)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
                .opacity(store.shotPlan.isEmpty ? 0 : 1)

            Spacer()

            Button {
                store.send(.closeButtonTapped)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    private func instructionCard(_ shot: ShotInstruction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shot.title)
                .font(.headline)
            Text(shot.direction)
                .font(.subheadline)
            Label("目安 \(shot.durationSeconds)秒", systemImage: "timer")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controls: some View {
        HStack(spacing: 40) {
            Button {
                store.send(.recordButtonTapped)
            } label: {
                Image(systemName: store.isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.system(size: 64))
                    .foregroundStyle(store.isRecording ? .white : AppColor.record)
            }

            Button {
                store.send(.nextShotButtonTapped)
            } label: {
                Label(
                    store.isLastShot ? "完了" : "次のカット",
                    systemImage: store.isLastShot ? "checkmark" : "arrow.right"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.accent)
            .disabled(store.shotPlan.isEmpty)
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    ShootView(
        store: Store(initialState: ShootFeature.State(theme: "カフェの紹介動画")) {
            ShootFeature()
        } withDependencies: {
            $0.directorClient = .liveValue
        }
    )
}
