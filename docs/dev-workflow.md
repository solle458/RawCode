### 開発ルール（Lint / Format / CI / 運用）（v0.1）

このドキュメントは、RawCode（Rust + Tauri + React/TypeScript）の開発における **フォーマット統一**、**静的解析**、**CI**、**日々の運用（jjフロー）** を最小のルールで破綻なく回すためのガイド。

前提（MVP）:

- macOS向けデスクトップ（Tauri）
- フロント: React + TypeScript（パッケージマネージャ: **pnpm**）
- バックエンド: Rust（**stableのみ**）
- 開発運用: **jj（Jujutsu）中心**、基本は **PRなし・main直push**
- コミットメッセージ: **Conventional Commits**
- フォーマット: 開発者側で自動整形（保存時/コミット時など）。CIは **チェックのみ**。
- Rust lint: **clippyはwarningもCIで落とす**

---

### 目的と方針

- **目的**: コードの読みやすさと品質を一定以上に保ちつつ、立ち上げ期の速度を落とさない。
- **方針**
  - **Formatは自動**（人が悩まない）
  - **Lint/型チェックは厳しめ**（後からの修正コストを抑える）
  - **CIは“同じコマンドを再現”**（ローカルで通る = CIでも通る）

---

### 1) ローカルで必ず通す（push前チェック）

PRなし運用では「サーバ側でCI成功を必須にしてmain直pushを拒否」は基本できないため、**push前にローカルでCI相当を通す**のをルールとする。

#### Rust（workspace想定）

- **Format**: `cargo fmt --all -- --check`
- **Lint**: `cargo clippy --workspace --all-targets --all-features -- -D warnings`
- **Test**: `cargo test --workspace`

補足:

- `rustfmt.toml` は **置かない**（デフォルト整形で統一）
- nightlyは **使わない**

#### Frontend（pnpm想定）

以下はリポジトリ構成が入ってから `package.json` のscriptsに寄せて統一する。

- **Format**: `pnpm prettier:check`（例: `prettier --check .`）
- **Lint**: `pnpm lint`（例: `eslint .`）
- **Typecheck**: `pnpm typecheck`（例: `tsc --noEmit`）
- **Test**: 未定（導入するならまず **Vitest** 推奨）

---

### 2) CI（GitHub Actions）で必ず回すチェック

CIは **自動修正しない（チェックのみ）**。修正はローカルで行う。

推奨ジョブ（最小）:

- **rust-check**
  - `cargo fmt --all -- --check`
  - `cargo clippy --workspace --all-targets --all-features -- -D warnings`
  - `cargo test --workspace`
- **frontend-check**
  - `prettier --check .`
  - `eslint .`
  - `tsc --noEmit`
  - （導入後）ユニットテスト（Vitest等）
- **security**
  - `cargo audit`（依存脆弱性チェック）

OS方針（当面）:

- **静的チェック/ユニットテストは基本ubuntuでOK**
- Tauriのビルド検証など、macOS固有が必要になった段階で **macosジョブを追加**

依存/ライセンス:

- `cargo audit` は **最初からCIに入れる**（導入が軽く効果が大きい）
- `cargo deny`（ライセンス/ポリシー）は **後回しでも良い**（依存が増えてきたタイミングで導入）

将来:

- miri / sanitizer は **将来導入**（まずは任意ジョブ or schedule（夜間/週次）から）

---

### 3) フォーマット / リンターの採用方針（推奨）

#### Rust

- `rustfmt`: デフォルト設定
- `clippy`: `-D warnings` で **warningも落とす**

#### TypeScript / React

- Prettier: 全体整形の基準
- ESLint: 厳しめ（未使用/unsafe/型回りを早期に検出）
- `tsc --noEmit`: 型の整合性ゲート
- CSS lint: `stylelint` は **未定**。CSS運用（CSS Modules / Tailwind / vanilla-extract等）が固まってから判断する。

---

### 4) jj運用（標準フロー）

標準フロー:

- `jj new`（作業開始）
- 実装（lint/formatを通す）
- `jj commit -m "<conventional message>"`
- 必要なら `jj bookmark set <name> -r @`
- `jj git push`

取り込み（基本）:

- `jj git fetch`
- 必要に応じてrebase/整列（運用が固まったら追記）

重要:

- **main直pushの品質担保は“push前のローカルチェック”が要**（上記 1)）

---

### 5) コミットメッセージ規約（Conventional Commits）

形式:

- `type(scope): summary`

例:

- `feat(raw_engine): add fast preview renderer`
- `fix(catalog): handle broken sidecar JSON`
- `chore(ci): add cargo audit job`

typeの目安:

- `feat` / `fix` / `refactor` / `perf` / `test` / `docs` / `chore`

---

### 6) 完了条件（このルールが機能している状態）

- 新規開発者が「push前に何を通すか」「CIが何を見ているか」を迷わない
- ローカルで通るものがCIでも通る（コマンドが一致）
- main直push運用でも、最低限の品質ゲートが運用として守れる

