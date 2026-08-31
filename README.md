# PdM スキルレーダー

Goodpatchの「PdM 35スキルマップ」をベースにした、プロダクトマネージャー向けの自己診断Webアプリです。
8カテゴリ・49項目のスキルを5段階で自己評価し、レーダーチャート・SWOT分析・MBTIとの掛け合わせ分析・
PdM偏差値・想定年収・キャリアパスまで無料で見える化します。

## 構成

| ファイル | 内容 |
|---|---|
| `index.html` | アプリ本体（HTML + CSS + JavaScript、単一ファイル） |
| `privacy.html` | プライバシーポリシー |
| `supabase_schema.sql` | Supabase用のテーブル定義・RLSポリシー・集計関数 |

外部ライブラリはCDN経由の Google Fonts と `@supabase/supabase-js` のみで、
ビルドツールやNode.js環境は不要です。ブラウザで `index.html` を開くだけで動作します。

## セットアップ（GitHub Pagesで公開する場合）

1. このリポジトリの **Settings → Pages** を開く
2. **Branch** を `main` / `/(root)` に設定して保存
3. 数分後、`https://<ユーザー名>.github.io/PdM/` で公開されます

## Supabase連携（履歴保存・アカウント同期を使う場合）

1. [supabase.com](https://supabase.com) でプロジェクトを作成
2. `supabase_schema.sql` の内容をSQL Editorで実行
3. **Authentication → Providers** で `Anonymous Sign-Ins` と `Email` を有効化
4. **Project Settings → API** から Project URL と anon (publishable) key を取得
5. `index.html` 冒頭にある以下の2箇所を書き換える

   ```js
   const SUPABASE_URL = "https://YOUR-PROJECT-ID.supabase.co";
   const SUPABASE_ANON_KEY = "YOUR-ANON-PUBLISHABLE-KEY";
   ```

未設定のままでも、ブラウザの `localStorage` を使った回答の保存・再開は動作します
（この場合、履歴のクラウド同期とメールでのアカウント連携のみ利用できません）。

## 独自ドメインで公開する場合

GitHub Pages / Netlify / Vercel / Cloudflare Pages のいずれも、管理画面から無料で
独自ドメインを接続できます。接続後は自動でHTTPS（SSL証明書）も発行されます。

## ライセンス・免責

本ツールはセルフチェック用の簡易診断です。PdM偏差値・想定年収・キャリアパス・公開求人情報は
いずれも参考情報であり、個人の適性や将来の収入を保証するものではありません。
