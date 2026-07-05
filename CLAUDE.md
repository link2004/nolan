# CueCam

AIが「どんな場面を撮影すればいいか」を指示し、ユーザーがその指示に従って動画を撮影できるカメラアプリ。映画監督の「キュー!」をAIが出す、が名前の由来。

## コアフロー

1. ホームでテーマを入力（例: 「カフェの紹介動画」）
2. AIディレクターがテーマからショットリスト（撮影指示のリスト）を生成
3. 撮影画面で1カットずつ指示を表示し、ユーザーが指示に従って録画
4. 全カット撮り終えたら完了

## アーキテクチャ

TCA (The Composable Architecture) ベースの3層構造（ADR-001参照）。

```
CueCam/
├── App/          # AppReducer（ルート）+ AppView
├── Features/     # HomeFeature, ShootFeature
├── Clients/      # DirectorClient（AI撮影指示生成）
├── Models/       # ShotInstruction
└── Design/       # AppColor
```

- プロジェクトファイルは XcodeGen 管理。`project.yml` を編集して `xcodegen generate` で再生成する（`.xcodeproj` はgit管理外）
- Bundle ID: `com.cuecam.app` / iOS 18.0+ / Team: 7LF5Z5CUCR

## 実装状況

- [x] プロジェクトスキャフォールド（TCA + XcodeGen）
- [x] HomeFeature: テーマ入力 → 撮影開始
- [x] ShootFeature: ショットリスト表示・カット送り（録画はUI状態のみ）
- [ ] CameraClient: AVFoundationでの実録画・プレビュー表示（`// TODO:` 参照）
- [ ] DirectorClient: Claude APIによる動的ショットリスト生成（現状は固定モック。`// TODO:` 参照）
- [ ] 音声読み上げによる指示（AVSpeechSynthesizer等）
- [ ] 撮影済みカットの確認・書き出し

## 一時実装・TODO

- `DirectorClient.liveValue` は固定モックのショットリストを返す仮実装
- `ShootFeature.recordButtonTapped` は `isRecording` フラグを切り替えるだけで実録画しない
- `ShootView` のカメラプレビューは黒背景のプレースホルダー

## 開発コマンド

```bash
xcodegen generate   # project.yml から .xcodeproj を再生成
xcodebuild -project CueCam.xcodeproj -scheme CueCam \
  -destination 'generic/platform=iOS Simulator' \
  -skipMacroValidation build   # ビルド確認（TCAのマクロ承認をCLIでスキップするため必須）
```
