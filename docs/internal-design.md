### 内部設計（v0.1）

このドキュメントは `docs/requirements.md` のMVP要件を満たすための、実装に直結する内部設計（アーキテクチャ／データ設計／レンダリング戦略／保存形式／IPC境界）を記述する。

### 前提と設計方針

- **対象**: macOS（MVP）
- **技術スタック**: Rust + LibRaw + Tauri + React/TypeScript
- **UI方針**: フロントは薄いビュー層。編集ロジック／履歴／レーティング／レンダリング制御はRust側で完結させる。
- **将来像**: `raw_engine` をライブラリとして切り出せる構造（アプリ依存を持たない）。
- **互換性**: Lightroom / Capture One との完全互換は重視しない（アプリ内完結を優先）。
- **履歴の永続化**: MVPでは不要。アプリ終了後に復元できるのは「最新の編集パラメータ＋レーティング」で十分。
- **対応フォーマット（MVP確定）**:
  - 入力（RAW）: **Sony `.arw` のみ**
  - 出力: **sRGB JPEG**（元解像度固定）
- **色管理（MVP方針）**:
  - プレビュー/書き出しは **常に sRGB** に揃える（見た目の一貫性を優先）

---

### Cargo workspace 構成（提案）

MVP時点からクレート境界を切り、将来の差し替え（DB化、タイル化、AI統合）に備える。

- `crates/raw_engine`
  - **目的**: RAW読み込み・現像・レンダリング・書き出しの中核。将来の切り出し対象。
  - **非目的**: Tauri / React / ファイルスキャン / レーティング管理。
- `crates/catalog_core`
  - **目的**: フォルダスキャン、写真一覧、サイドカー読み書き（MVP）。将来DB化の境界を提供。
- `crates/edit_core`
  - **目的**: `DevelopParams` 更新、ヒストリ（Undo/Redo）、Before/Afterの基準管理。
- `crates/app_core`
  - **目的**: UIイベントを受けて、状態更新とレンダリング要求をオーケストレーション（ジョブ制御含む）。
- `crates/tauri_bridge`（アプリ）
  - **目的**: Tauri command 群の公開、フロントへのデータ返却（画像bytes等）。

---

### ドメインモデル（MVP）

#### Photo / ID

- `PhotoId`
  - MVPでは `raw_path` 由来で良い（将来DB導入時にUUID等へ差し替え可能な形にする）。
- `Photo`
  - `raw_path`
  - `sidecar_path`
  - `metadata`（必要最低限。exifなどは段階導入）

#### 永続化する状態（サイドカー）

- `PhotoState`
  - `rating: u8`（0..=5）
  - `params: DevelopParams`（最新値）
  - `version: u32`（将来マイグレーション用）
  - `last_modified`（任意）

#### 編集パラメータ（MVP）

- `DevelopParams`
  - exposure
  - contrast
  - highlights
  - shadows
  - black
  - white
  - saturation
  - vibrance
  - temperature

##### スライダー値域（MVP確定）

UIは下記の値域で受け付け、Rust側のレンダリング実装（LibRaw設定・独自トーンマップ等）へマッピングする。

- `exposure`: **-5.0..=+5.0**（EV）
- `contrast`: **-100..=+100**
- `highlights`: **-100..=+100**
- `shadows`: **-100..=+100**
- `black`: **-100..=+100**
- `white`: **-100..=+100**
- `saturation`: **-100..=+100**
- `vibrance`: **-100..=+100**
- `temperature`: **2000..=12000**（K）

デフォルトは「編集なし」を表す値（各項目0相当。temperatureはRAWのWB相当を初期値にしても良い）。

#### ヒストリ（メモリのみ）

- `History`
  - 「スライダー1操作=1ステップ」
  - Undo/Redo可能（MVP）
- `HistoryEntry`
  - `param_id`
  - `from`
  - `to`
  - `timestamp`

##### ヒストリ上限（MVP確定）

- 最大 **50ステップ**
- Undoで過去に戻った後に新しい編集を行った場合、Redo枝は破棄する（一般的なUndo仕様）

---

### Viewport（ズーム／パン）設計

ズーム／パンは将来のタイル／再レンダリングを見据え、Rust側で一貫して管理する。

- `Viewport`
  - `zoom: f32`
  - `center: (f32, f32)`（画像座標を 0..1 に正規化）
  - `fit_mode`（Fit/Fill/100% など、初期表示の再現性用）

フロントは `Viewport` を送るだけで、描画更新はRustが返すプレビューで行う。

---

### レンダリング設計（2段階プレビュー）

スライダー操作の体感を優先し、レンダリング品質を2段階にする。

- **Dragging（操作中）**
  - 低解像度（例: 1024px幅）で即応
  - 最新入力のみを生かし、それ以前のレンダリングジョブはキャンセルする
- **Commit（操作確定）**
  - 高品質（表示解像度相当〜やや大きめ）で再レンダリングし、表示を置換する

`raw_engine` 側のAPIは将来タイル化できるように、要求として品質・viewport・出力サイズを受け取る。

- `RenderQuality`
  - `FastPreview`
  - `HighPreview`
  - `Tile`（将来）
- `RenderRequest`
  - `photo`（RawSession参照等）
  - `params: DevelopParams`
  - `viewport: Viewport`
  - `quality: RenderQuality`
  - `target_size` または `tile_size`

---

### 保存（サイドカー）設計（確定）

#### 配置（確定）

- 対象フォルダ直下に **`.rawcode/`** を作り、その配下にサイドカーを保存する。
- **移動耐性**: 同一フォルダ内運用前提（フォルダごとコピー／移動を想定）。RAW単体移動への追従はMVPでは行わない。

#### 命名規則（推奨）

RAW `basename` をキーにサイドカーを決定する（拡張子衝突が問題になる場合は拡張子も含める）。

- 例（単純）: `.rawcode/DSC_0001.json`
- 例（衝突回避）: `.rawcode/DSC_0001.nef.json`

#### フォーマット（推奨：JSON）

- 互換性を重視しないため、MVPは独自JSONを採用する。
- 内容は `PhotoState`（rating + params + version）に限定し、履歴は保存しない。

#### サイドカー破損時（MVP確定）

- `.rawcode/*.json` が不正（JSONパース不可、欠損）な場合は **該当写真のみ** 初期状態として扱う。
  - `rating=0`
  - `params` はデフォルト（編集なし）
- 破損は「全体停止」にはしない（MVPの実用性優先）

---

### catalog_core のストア境界（将来DB化）

MVPはサイドカー（ファイル）ストアだが、将来 `CatalogStore` を差し替えてDB化できる構造にする。

- `CatalogStore`（例）
  - `load(photo_id) -> Option<PhotoState>`
  - `save(photo_id, state: &PhotoState) -> ()`

MVP実装: `SidecarStore`（`.rawcode/` に読み書き）
将来実装: `DbStore`（カタログDB等）

---

### IPC（Tauri commands）設計（骨子）

フロントを薄くするため、フロントは状態を持ちすぎず、Rust主導で更新する。

- `select_folder(path) -> PhotoList`
- `select_photo(photo_id) -> PhotoViewState`（rating, params, metadataなど）
- `set_param(photo_id, param, value, phase: Dragging|Commit) -> PreviewBytes`
- `set_rating(photo_id, rating) -> ok`
- `undo(photo_id) -> PreviewBytes`
- `redo(photo_id) -> PreviewBytes`
- `set_viewport(photo_id, viewport) -> PreviewBytes`
- `export_jpeg(photo_id, out_path) -> ok`（MVPは sRGB JPEG 固定）

#### `export_jpeg`（MVP詳細）

- 画質はプリセットで受け取る（UIは高画質/普通/低画質）:
  - `High`（quality=95）
  - `Medium`（quality=85）
  - `Low`（quality=70）
- 解像度は元解像度固定（将来オプション化）
- メタデータは **MVPでは付与しない**（安全優先。将来必要なら最小限から追加）

`PreviewBytes` はフロントで表示可能な形式（例: PNG/JPEG bytes）とする。将来的に性能要件が上がれば共有メモリ等へ拡張する。

---

### 非機能（MVPのガードレール）

- **プレビュー体感**: 操作中は低解像度即応、操作確定後に高品質へ置換。
- **品質優先**: 最終的に「そこそこちゃんとした画質」でプレビューできること。
- **拡張性**: DB化（catalog）、タイルレンダリング（raw_engine）、AI統合（app_core）を後から載せられる境界を確保する。

---

### サムネ生成/キャッシュ（MVP推奨）

初回ロード体験を優先し、サムネは以下の順で生成する。

1. RAW内の **埋め込みJPEG** を取得できればそれを使用（最速）
2. 取得できない場合のみ `FastPreview` 相当の低解像度現像で生成（フォールバック）

キャッシュ:

- `.rawcode/thumbs/` にサムネをキャッシュする（MVP推奨）
- キーは `raw_path` + `target_size` + `raw_mtime` 等で十分（MVP）

