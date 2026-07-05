# ADR-001: TCA + XcodeGen によるプロジェクト構成

日付: 2026-07-05
ステータス: 採用

## コンテキスト

CueCam（AI撮影指示カメラアプリ)の新規立ち上げにあたり、アーキテクチャとプロジェクト管理方式を決める必要があった。

## 決定

1. **TCA (The Composable Architecture) を採用**し、Features / Clients / Design の3層構造とする
   - グローバルルール（swift-architectureスキル）の標準構成に準拠
   - 既存プロジェクト（youlet-mark3）と同じパターンで学習コストゼロ
   - カメラ・AI通信など外部依存が多いアプリのため、`@DependencyClient` によるモック差し替えがテストで効く
2. **XcodeGen でプロジェクトファイルを管理**する
   - `.xcodeproj` はgit管理外、`project.yml` が唯一のソース
   - CLIからの再現・マージコンフリクト回避のため
3. youlet-mark3 の慣習を踏襲: iOS 18.0+ / Team 7LF5Z5CUCR / `com.<app>.app` 形式のBundle ID

## 影響

- ファイル追加時は `xcodegen generate` の再実行が必要（sourcesはディレクトリ指定なので自動で拾われる）
- AI指示生成は `DirectorClient`、カメラ操作は将来の `CameraClient` に閉じ込め、Reducerは純粋に保つ
