import ComposableArchitecture
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            Form {
                ForEach(VaultSurface.allCases) { surface in
                    Section(surface.label) {
                        TextField(
                            "http://<MacのIP>:ポート",
                            text: Binding(
                                get: { store.urls[surface] ?? "" },
                                set: { store.send(.urlChanged(surface, $0)) }
                            )
                        )
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.callout.monospaced())

                        probeRow(store.probes[surface] ?? .unknown)
                    }
                }

                Section {
                    Button("接続を確認") { store.send(.probeAll) }
                } footer: {
                    Text("シミュレータでは localhost、実機ではMacのIPアドレス(例: http://192.168.1.10:8750)を指定してください。接続できない場合はiOS設定のローカルネットワーク許可を確認してください。")
                }
            }
            .navigationTitle("設定")
        }
        .task { store.send(.task) }
    }

    @ViewBuilder
    private func probeRow(_ status: ProbeStatus) -> some View {
        HStack(spacing: 8) {
            switch status {
            case .unknown:
                Circle().fill(.gray).frame(width: 10, height: 10)
                Text("未確認").foregroundStyle(.secondary)
            case .checking:
                ProgressView().controlSize(.small)
                Text("確認中…").foregroundStyle(.secondary)
            case .ok(let ms):
                Circle().fill(.green).frame(width: 10, height: 10)
                Text("接続OK (\(ms)ms)")
            case .failed(let message):
                Circle().fill(.red).frame(width: 10, height: 10)
                Text(message).foregroundStyle(.red).lineLimit(2)
            }
        }
        .font(.footnote)
    }
}
