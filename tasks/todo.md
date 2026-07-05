# CueCam タスク

## プロジェクト立ち上げ (2026-07-05)

- [x] XcodeGen + TCA でプロジェクトスキャフォールド作成
- [x] HomeFeature（テーマ入力）
- [x] ShootFeature（撮影指示の表示・カット送り）
- [x] DirectorClient（モック実装）
- [x] ビルド確認
- [x] git init

## 次にやること

- [ ] CameraClient: AVCaptureSession でプレビュー + 録画（実機必須）
- [ ] DirectorClient: Claude API で動的ショットリスト生成（APIキー管理は secret-via-pbpaste 参照）
- [ ] 撮影指示の音声読み上げ
- [ ] 撮影済みカットのレビュー画面・フォトライブラリ保存

## レビュー

立ち上げ完了。録画とAI生成はスタブ（CLAUDE.md「一時実装・TODO」参照）で、UIフロー（テーマ入力 → 指示表示 → カット送り → 完了）はシミュレータで動作する状態。
