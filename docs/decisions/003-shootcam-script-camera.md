# ADR-003: スクリプト付き撮影フロー(ShootFeature)と ShootCam 起動ターゲット

日付: 2026-07-05
状態: 採用

## 文脈

CueCam 本体が Ten-K Vault 読み取り専用クライアントへピボット(ADR-002)するのと並行して、旧構想由来の「AIディレクターが撮影スクリプトを出し、ユーザーが従って撮る」カメラ体験を **同じプロジェクトの別機能** として作ることになった(ユーザー決定)。

要件(ユーザー指定のコアフロー):

- 横持ち(ランドスケープ)のカメラ
- 画面下に撮影内容のスクリプトを表示
- 録画 → 撮影後プレビュー(ループ再生) → OKなら次のスクリプトへ
- 撮影対象は動画のみ。スクリプトは当面ハードコードのモック

## 決定

1. **機能コードは正規の3層構造に置く**: `Features/ShootFeature/`(状態機械+View)、`Clients/CameraClient.swift`(AVCaptureSession抽象化)、`Models/ShotScript.swift`。`CueCam` ターゲットは `sources: [CueCam]` なのでこれらも自動的にコンパイル対象になり、将来タブとして組み込む際の移動が不要。
2. **起動用に軽量ターゲット `ShootCam` を追加**(bundle id: `com.cuecam.shootcam`、横向き固定、カメラ/マイク権限付き)。CueCam 本体のルートが並行開発中のため、ShootFeature 単体を実機で回すための開発用シェル。エントリは `ShootCam/ShootCamApp.swift`(`CueCam/` ディレクトリ外に置き、本体ターゲットへの @main 混入を防ぐ)。
3. **CameraClient は @DependencyClient + 専用シリアルキューの CameraManager**。録画完了は `AVCaptureFileOutputRecordingDelegate` を continuation でブリッジ。録画開始コールバック前の停止要求(超高速タップ)は `pendingStop` フラグで吸収。
4. **回転は `videoRotationAngle` を手動マッピング**(landscapeRight=0°/landscapeLeft=180°)。プレビューは `layoutSubviews`、録画は開始時に interfaceOrientation から設定。`AVCaptureDevice.RotationCoordinator` はスレッド要件が不明瞭なため見送り。

## 帰結

- ShootFeature の状態機械: `preparing → ready ⇄ recording → reviewing → (次のスクリプト | finished)`。承認済みテイクは `approvedTakes: [Int: URL]`(一時ディレクトリ)に保持 — 書き出し機能は未実装。
- CueCam 本体(閲覧専用コンセプト)にカメラ体験をどう統合するか(タブ追加 or 別アプリ化)は未決。統合時は CueCam 側 Info.plist にカメラ/マイク権限の追加が必要。
- ShootCam ターゲットは統合後に削除予定。
