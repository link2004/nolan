# ADR-004: Storyboard → 撮影ワークフロー統合

日付: 2026-07-05
状態: 採用

## 文脈

ShootFeature(ADR-003)は ShootCam シェルターゲット単体で動いており、スクリプトは固定モックだった。ユーザー要望により、CueCam 本体の Storyboard タブから撮影に入り、**そのボードの内容が撮影スクリプトとして出てくる**ワークフローにする。

## 決定

1. **スクリプトは AI 生成ではなく `SBBoard` の直接マッピング**。`SBBoard.shotScripts`(`Models/SBBoard+ShotScripts.swift`)が beats × lines を撮影順に平坦化する。対象は**全ライン**(参照メディアはインスピレーションと見なす — ユーザー決定)。メイン指示は `script` → `shot_direction` → `beat.heading` のフォールバック。
   - この拡張を ShotScript.swift と別ファイルにしているのは、StoryboardModels を含まない ShootCam ターゲットから SBBoard 依存を切るため。
2. **エントリポイントはボード画面のツールバー「Shoot」ボタン**。`BoardFeature` が `@Presents var shoot: ShootFeature.State?` で fullScreenCover 表示し、`delegate(.close)` で閉じる。閉じる時に `cameraClient.stopSession()` を親側で呼ぶ(ifLet の効果キャンセルと競合させないため)。
3. **撮影画面のみ横向き**。CueCam の Info.plist に landscape を追加しつつ、`OrientationLockDelegate`(@UIApplicationDelegateAdaptor)が既定 `.portrait` を返し、ShootView の onAppear/onDisappear で `.landscape` ⇄ `.portrait` を切り替える。
4. **読み取り専用原則(ADR-002)は維持**。撮影テイクはローカル一時ファイルのみで、サーバーへの書き戻しはしない。

## 帰結

- ShotScript は String id(`"beat.id/line.id"`)+ slate / direction / techniques を持つ形に拡張。approvedTakes のキーも String に変更
- ShootCam 単体起動はモックスクリプトのまま動作(リグレッションなし)
- カバレッジ(filled/empty)は撮影対象の絞り込みに使っていない。「空のラインだけ撮る」モードは将来の拡張余地
- テイクの書き出し・ボードへの紐付けは未実装(次ステップ)
