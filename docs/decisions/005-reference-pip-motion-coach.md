# ADR-005: 参照PiP・カメラロール保存・モーションコーチ

日付: 2026-07-05
状態: 採用

## 文脈

Storyboard → Shoot ワークフロー(ADR-004)に対するユーザー要望: (1) ラインの参照メディアを撮影中に右上へ小さくループ再生 (2) テイク承認でカメラロールに保存して次のラインへ (3) 「AIコーチ」がカメラの動き(ウィップパン・俯瞰・ティルト・ドリー等)を矢印の描画アニメーションで教える。

## 決定

1. **参照PiP**: `ShotReference`(URL解決済み・SBReference非依存)を `ShotScript` に追加し、マッピング時に `MediaURL.url(key:)` で解決。クリップは共通 `LoopingPlayerView` に `isMuted`/`gravity` を追加して**ミュート**ループ再生(録画マイクへの音漏れ防止)。4:5・幅100ptで右上(録画ボタンの上)。
2. **カメラロール保存は「OK, Next での承認時」**。録画停止直後ではない — Retake したテイクをカメラロールに残さないため、既存レビューフローと整合させた。`PhotoLibraryClient`(PHPhotoLibrary add-only)を新設し、保存はUI非ブロックの裏エフェクトで実行、失敗のみバナー通知。
3. **モーションコーチはキーワードマッピング(AI呼び出しなし)**。実データ調査で `technique` は美学タグ("Golden hour"等)であり、カメラモーションは `shot_direction` の自由文に入っていると判明。`MotionCoach.detect` が正規表現で 11 種(pan L/R・whip pan・tilt U/D・top-down・dolly in/out・track・orbit・handheld)に分類する。
4. **「描いている」表現は Shape の trim アニメーション**。矢じりまで含めた1本のパスを trim 0→1 でループ描画し、手描きアノテーションのように見せる(`MotionGlyph`)。待機中はプレビュー中央に大きく、録画中は左上に小さく半透明で表示継続。

## 帰結

- 検出は英語の撮影指示語彙に依存。DirectorClient(Claude API)導入時にはAI側でモーションを構造化して返す置き換え候補(コード内 `// TODO:`)
- 検出漏れ・誤検出はラベル表示で気付ける。該当なしの場合は何も表示しない
- ShootCam 単体ターゲットに PhotoLibraryClient.swift を追加。モックスクリプトは各モーションのデモを兼ねる
