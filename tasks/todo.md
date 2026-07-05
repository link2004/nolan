# CueCam タスク

## Storyboard → 撮影ワークフロー統合 (2026-07-05)

ボード画面の Shoot ボタンから撮影フローへ。スクリプトは SBBoard の beats/lines から直接マッピング(全ライン対象、ADR-004)。

- [x] ShotScript 拡張(String id / slate / direction / techniques) + SBBoard.shotScripts
- [x] ShootFeature: title / showsClose / delegate(.close) / approvedTakes を String キーに
- [x] ShootView: スレート・direction・チップ表示 / 閉じるボタン / Done / 横向きロック
- [x] OrientationLock(撮影画面のみ横向き)
- [x] BoardFeature/BoardView: @Presents shoot + ツールバー Shoot ボタン + fullScreenCover
- [x] CueCamApp: OrientationLockDelegate 接続 / project.yml: CueCam に横向き+カメラ/マイク権限
- [x] CueCam / ShootCam 両スキームのシミュレータビルド確認
- [ ] CueCam 実機インストール(並行セッションのビルドと DerivedData が競合(database is locked)したため保留。再実行: `device_build.sh . CueCam`)
- [x] ドキュメント(ADR-004 / CLAUDE.md / todo)

## スクリプト付き撮影フロー: ShootFeature + ShootCamターゲット (2026-07-05)

横持ちカメラ + 下部スクリプト表示 + 録画→プレビュー→OKで次へ、のコアフロー(ADR-003)。

- [x] ShotScript モデル(モック5本)
- [x] CameraClient(AVCaptureSession / MovieFileOutput 抽象化)
- [x] ShootFeature(状態機械) + ShootView + CameraPreviewView
- [x] ShootCam 起動ターゲット追加(横向き固定・カメラ/マイク権限)
- [x] シミュレータビルド確認 + 実機(Streamland)インストール・起動
- [ ] 実機での一連フロー動作確認(ユーザーによる: 録画→プレビュー→OK→次カット、映像の向き)
- [ ] DirectorClient: Claude API でスクリプト動的生成
- [ ] 承認テイクの書き出し(フォトライブラリ保存)
- [ ] CueCam 本体への統合方針決定(タブ追加 or 別アプリ化)

### レビュー

実装完了・実機起動済み。機能コードは正規3層(Features/Clients/Models)に置き、CueCam本体のルート(並行開発中)には触れず ShootCam シェルターゲットから起動する構成にした。device_build.sh はスキーム名≠プロジェクト名だと .app を見つけられない(DerivedDataはプロジェクト名で作られる)ため、install/launch は devicectl で手動実行した。

## Ten-K Vault クライアントへのピボット (2026-07-05)

計画: `~/.claude/plans/crispy-watching-elephant.md`。旧AIディレクターカメラのタスクは廃止(コードはベースラインcommit c6ddaf5 に保存)。

- [x] Phase 0: ベースラインcommit → Home/Shoot/Director削除 → TabViewルート → project.yml (ATS/local network)
- [x] Phase 1: Models + MediaURL + 3クライアント + SettingsFeature(プローブ)
- [x] Phase 2: Wiki(WikiClient actor + エクスプローラ/ノート/検索/バックリンク)
- [x] Phase 3a: Storyboard(プロジェクト一覧 + ボード、静止画のみ)
- [x] Phase 3b: InlineClipPlayer + PlayerPool + フルスクリーン再生
- [x] Phase 4: Vaultspace(マップキャンバス + 詳細シート)
- [ ] ビルド確認(xcodegen + xcodebuild は後段のビルドエージェントが実行)
- [ ] Phase 5: 検索・リフレッシュ・エラー状態の仕上げ
- [x] ドキュメント: CLAUDE.md書き換え + ADR-002
