# RawCode

RAW初心者〜中級者向けの「大量の写真をサクサク選別し、そこそこ高画質で現像できる」macOSデスクトップアプリ（MVPはmacOS限定）。

## Docs

- `docs/requirements.md`: 要件定義（MVPスコープ）
- `docs/external-design.md`: 外部設計（画面/操作/エラー/設定）
- `docs/internal-design.md`: 内部設計（アーキテクチャ/データ/レンダリング/保存/IPC）

## MVPの確定事項（抜粋）

- **対応RAW**: Sony `.arw` のみ
- **書き出し**: sRGB JPEG（元解像度固定、品質プリセット: 高画質/普通/低画質）
- **色管理**: MVPは常に sRGB（プレビューと書き出しの見た目一致を優先）
- **サイドカー**: 対象フォルダ直下 `.rawcode/` に保存