# ADR-002: Ten-K Vault 読み取り専用クライアントへのピボット

日付: 2026-07-05
ステータス: 採用

## コンテキスト

CueCamは当初「AIが撮影指示を出すディレクターカメラ」として立ち上げたが、Ten-K Vault(Obsidianボルト + Aftertasteパイプライン)の内容をiPhoneから閲覧したいニーズが優先された。Vault側には既にMac上で動く3つの閲覧サーバー(Quartz / Storyboard Studio / Vaultspace)が存在する。

## 決定

1. **CueCamを Ten-K Vault の読み取り専用iOSクライアントにピボットする**
   - Wiki / Storyboard Studio / Vaultspace の3タブ + 設定タブの構成
   - 閲覧のみ。Vault側への書き込み・編集機能は持たない
2. **ネイティブSwiftUIで再実装する(WKWebView不採用)**
   - 既存Webページのラップではなく、各サーバーのJSON APIを直接叩いてネイティブUIで描画する
   - オフライン耐性・スクロール/再生性能・iOSらしい操作感を優先
3. **Macローカルサーバーに接続する**
   - Quartz :8750 / `serve_storyboard.py` :8731 / `serve_vaultspace.py` :8765
   - ベースURLは設定タブで変更可能。ATSは `NSAllowsLocalNetworking` で許可
   - backend(ten-k-vault側)のコードは変更しない — アプリが既存APIに合わせる
4. **旧Home/Shoot(AIディレクターカメラ)は削除する**
   - コードはベースラインcommit `c6ddaf5` に保存済みで、必要になれば復元できる
   - カメラ/マイク/フォトライブラリの使用許可もInfo.plistから削除

## 影響

- ADR-001のTCA + XcodeGen構成はそのまま踏襲(Features / Clients / Models / Networking / Design)
- `DirectorClient` / 将来の `CameraClient` 構想は廃止し、WikiClient / StoryboardClient / VaultspaceClient / ServerConfigClient に置き換え
- LANメディア(静止画/クリップ)のキャッシュのため `URLCache.shared` を 20MB/100MB に拡張
- メディアURLはサーバーがR2へ302することがある(URLSession/AVPlayerの自動追従に依存)
