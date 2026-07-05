# CueCam — Ten-K Vault 読み取り専用iOSクライアント

Mac上のTen-K Vault(Obsidianボルト + Aftertasteパイプライン)を、iPhoneから閲覧するためのネイティブSwiftUIアプリ。Wiki / Storyboard Studio / Vaultspace の3サーフェス + 設定の4タブ構成。**閲覧のみで、Vault側への書き込みは一切行わない**(ADR-002参照)。

旧「AIディレクターカメラ」からのピボット。旧コードはベースラインcommit `c6ddaf5` に保存済み。

## アーキテクチャ

TCA (ComposableArchitecture 1.17) ベース。Swift 6 strict concurrency / iOS 18.0+。

```
CueCam/
├── App/          # AppReducer(TabViewルート: wiki/storyboard/vaultspace/settings) + AppView
├── Features/     # WikiFeature, ProjectsFeature(Storyboard), VaultspaceFeature, SettingsFeature
├── Clients/      # WikiClient, StoryboardClient, VaultspaceClient, ServerConfigClient(@DependencyClient)
├── Models/       # ServerConfig(VaultSurface/LoadState), WikiModels, StoryboardModels, VaultspaceModels
├── Networking/   # HTTP(getJSON/baseURL), MediaURL(メディアキーのURL組み立て)
└── Design/       # AppColor
```

- 全モデルは `Sendable`。UI可変状態は `@MainActor` に隔離
- CueCamApp.init() で `URLCache.shared` を 20MB/100MB に拡張(LANメディアのキャッシュ用)
- メディアURL: サーバーがR2へ302リダイレクトすることがある(URLSession/AVPlayerは自動追従)

## バックエンド接続(Mac上のローカルサーバー3系統)

| サーフェス | サーバー | ポート |
|---|---|---|
| Wiki | Quartz (静的サイト) | :8750 |
| Storyboard | `serve_storyboard.py` | :8731 |
| Vaultspace | `serve_vaultspace.py` | :8765 |

- ベースURLは `ServerConfigClient` が保持し、設定タブで変更・到達性プローブが可能
- **読み取り専用。backend(ten-k-vault側)のコード変更は禁止** — このアプリはサーバーの既存APIに合わせる
- Info.plist: `NSAllowsLocalNetworking` + `NSLocalNetworkUsageDescription` でLAN接続を許可

## 実装状況

- [x] Phase 0: ピボット土台(旧Home/Shoot削除、TabViewルート、ATS/ローカルネットワーク設定)
- [x] Phase 1: Models + MediaURL + 3クライアント + SettingsFeature(プローブ)
- [x] Phase 2: Wiki(エクスプローラ/ノート/検索/バックリンク)
- [x] Phase 3: Storyboard(プロジェクト一覧 + ボード + クリップ再生)
- [x] Phase 4: Vaultspace(マップキャンバス + 詳細シート)
- [ ] ビルド確認(実機/シミュレータでの動作検証は未)
- [ ] Phase 5: 検索・リフレッシュ・エラー状態の仕上げ

## 開発コマンド

```bash
xcodegen generate   # project.yml から .xcodeproj を再生成
xcodebuild -project CueCam.xcodeproj -scheme CueCam \
  -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation build   # ビルド確認(TCAのマクロ承認をCLIでスキップするため必須)
```

- プロジェクトファイルは XcodeGen 管理。`project.yml` が唯一のソース(`.xcodeproj` はgit管理外)
- Bundle ID: `com.cuecam.app` / iOS 18.0+ / Team: 7LF5Z5CUCR

## 設計決定

- ADR-001: TCA + XcodeGen によるプロジェクト構成(`docs/decisions/001-tca-xcodegen.md`)
- ADR-002: Ten-K Vault 読み取り専用クライアントへのピボット(`docs/decisions/ADR-002-ten-k-vault-client-pivot.md`)
