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
                            "http://<Mac IP>:port",
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
                    TextField(
                        "https://media.example.com",
                        text: Binding(
                            get: { store.mediaURL },
                            set: { store.send(.mediaURLChanged($0)) }
                        )
                    )
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.callout.monospaced())
                } header: {
                    Text("Media")
                } footer: {
                    Text("Images and clips load directly from this host (Cloudflare R2), not through the Mac.")
                }

                Section {
                    Button("Check connections") { store.send(.probeAll) }
                } footer: {
                    Text("Use localhost in the simulator, or your Mac's LAN IP on a device (e.g. http://192.168.0.215:8750). If a server is unreachable, check Local Network permission in iOS Settings.")
                }
            }
            .navigationTitle("Settings")
        }
        .task { store.send(.task) }
    }

    @ViewBuilder
    private func probeRow(_ status: ProbeStatus) -> some View {
        HStack(spacing: 8) {
            switch status {
            case .unknown:
                Circle().fill(.gray).frame(width: 10, height: 10)
                Text("Not checked").foregroundStyle(.secondary)
            case .checking:
                ProgressView().controlSize(.small)
                Text("Checking…").foregroundStyle(.secondary)
            case .ok(let ms):
                Circle().fill(.green).frame(width: 10, height: 10)
                Text("Connected (\(ms)ms)")
            case .failed(let message):
                Circle().fill(.red).frame(width: 10, height: 10)
                Text(message).foregroundStyle(.red).lineLimit(2)
            }
        }
        .font(.footnote)
    }
}
