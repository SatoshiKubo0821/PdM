# AI プロダクト開発診断（/diagnosis）— 引き継ぎメモ

プロダクト開発チームの現状（As-Is）を観点別の問診票で集め、AI が症状・根本原因・観点間の矛盾・見落としを分析するツール。
公開 URL は `https://pdmquest.com/diagnosis/`（GitHub Pages、`main` の `/diagnosis/index.html` がそのまま配信される）。

このフォルダの作業は、リポジトリ直下の PdM スキルレーダー（`/index.html` など）とは独立している。直下のファイルには触れないこと。

## プロダクトの方針（オーナー: Satoshi）

- 「AI プロダクト開発診断」は、プロダクト開発の課題を抽出し、深い分析と示唆まで出すプロダクト。
- **第1段階は As-Is（現状）分析**。To-Be や解決策の提案はまだ出さない。結果の最後の「To-Be 検討の前に決める論点」が次段階への接続点。
- 利用者のリテラシーに差があるため、入力欄は観点ごとに分け、各欄に問いかけと記入例を付け、迷いやすい項目は選択式にしている。空欄は「情報不足」として診断に使う。
- UI 文言はすべて日本語、です・ます調。

## ファイル構成

- `index.html` … アプリ本体。HTML・CSS・JS をすべて含む単一ファイル。ビルド不要。
- 外部依存は Google Fonts と、Excel 取り込み時にだけ動的に読み込む SheetJS（cdnjs `xlsx/0.18.5`）のみ。

## 実行環境は 2 系統（`engine` 変数）

`index.html` は 1 つのソースで両方に対応している。

| engine | いつ | AI 呼び出し |
|---|---|---|
| `artifact` | claude.ai の Artifact として開いたとき（`window.claude` がある） | `claude.use('sample')` の `sample.json()`。閲覧者の Claude 利用枠を使う。画像は `capabilities: {sample: {images: true}}` の宣言が必要 |
| `api` | それ以外（pdmquest.com など） | 画面で入力した Anthropic API キーで `https://api.anthropic.com/v1/messages` をブラウザから直接ストリーミング呼び出し（`anthropic-dangerous-direct-browser-access: true`）。`apiJSON()` |

どちらも使えないときは「診断用プロンプトをコピー」で Claude に貼り付ける運用にフォールバックする。
claude.ai 版の Artifact は Claude.ai の別会話で公開したもので、このリポジトリとは自動同期しない。Artifact として公開し直す場合は `<!doctype>`〜`<body>` を外した中身を使う。

## データモデル

```js
S = {
  values: { [fieldId]: string | string[] | object },  // 入力値
  self:   { [perspectiveId]: 0..5 | null },           // 自己評価（0 = わからない）
  result: 診断結果 JSON | null,
  isSample, resultSample                               // サンプル表示中フラグ
}
```

- `localStorage['aipd-asis-v1']` に丸ごと保存（`save()` / `loadStore()`）。初回はサンプル（`useSample()`）を表示。
- API キーは `localStorage['aipd-api-key']`（「このブラウザにキーを保存」にチェックしたときだけ）、モデル選択は `aipd-model`。
- 取り込んだ画像は `IMGS`（メモリのみ。保存されない）。

## 観点の定義（`const P`）

問診票は `P` 配列から `buildForm()` で生成される。観点を足す・変えるときは基本的に `P` を編集すればよい。

- 観点: `basic`(00) / `customer`(01) / `value`(02) / `market`(03) / `business`(04) / `strategy`(05) / `org`(06) / `team`(07 開発体制と工数) / `process`(08) / `tech`(09) / `data`(10) / `pain`(11)
- `self:false` の観点（`basic`, `pain`）は自己評価なし・スコア対象外。それ以外が `SCORED` で、レーダーチャートの軸になる。
- フィールドの `type`:
  - 省略 … textarea / `text` … 1 行入力
  - `one` / `multi` … チップ選択（単一・複数）
  - `month` … 年月入力。`calc:'since'|'until'` で経過・残り期間を表示
  - `number` … 数値＋単位（`unit`）。`half:true` で 2 列配置
  - `members` … メンバー表（職種・人数・稼働率・雇用形態）。`memberStats()` が合計人数・実働人月/月・社外比率を計算
  - `split` … 工数の使い道の割合（`SPLIT` 定義）。合計 100% を促す
  - `import` … ロードマップ取り込み（CSV / TSV / TXT / MD / JSON / Excel / 画像）。表データは `values.roadmapData` にテキストとして入り（上限 `MAX_DATA` = 24,000 字）、ファイル一覧は `values.roadmapFiles`

## AI への入力と出力

- `buildPrompt()` が指示文＋出力 JSON スキーマ＋`dump()`（全観点の記入内容を Markdown 化。`fmtField()` が型ごとに整形し、人月などの集計値も添える）を組み立てる。
- 出力 JSON の形（`renderResult()` と `toMd()` がこれを前提にしている）:
  - `headline`, `summary`, `maturity`(1–5)
  - `perspectives[]`: `id, score(1–5|null), state(良好|注意|危険|情報不足), finding, evidence[], selfGap`
  - `coreIssue`: `title, explanation`
  - `issues[]`: `title, severity(高|中|低), symptom, rootCauses[], perspectives[], why`
  - `contradictions[]`: `a, b, insight`
  - `blindSpots[]`, `questions[]`(`perspective, question, why`), `implications[]`
- スキーマを変えたら `buildPrompt()`・`renderResult()`・`toMd()`・`SAMPLE_RESULT` の 4 か所を揃えること。

## 画面と主な関数

- 問診票: `buildForm()` → `paintForm()`（状態を画面に反映）→ `meters()`（観点別・全体の記入率）
- 入力イベントは document への委譲（`input` / `click`）。メンバー表は `data-m` / `data-k`、工数割合は `data-split`、通常欄は `data-f`
- 結果: `renderResult()`（総合所見・レーダー `radar()`・観点別表・課題の構造・矛盾・見落とし・問い・論点）、`toMd()` で Markdown コピー
- エラー文言は `ERR`（コード → 利用者向けの日本語）

## デザイン

- カルテ（診療録）がモチーフ。左に観点インデックス、右に問診票、下に診断所見。
- 色・書体は `:root` のトークンで管理し、ライト／ダーク両対応（`prefers-color-scheme` と `data-theme`）。アクセントは深いティール、状態色（良好・注意・危険・情報不足）はアクセントと別系統。
- 書体: 見出し Shippori Mincho B1 / 本文 IBM Plex Sans JP / ラベル・数値 IBM Plex Mono。
- 幅 390px でも横スクロールが出ないこと（表とメンバー表だけは内部スクロール）。

## 確認のしかた

ビルドもテストランナーもない。変更後は最低限:

1. スクリプトの構文チェック: `<script>` の中身を取り出して `node --check`
2. ブラウザで開き、サンプル表示・入力・クリア・取り込み・診断（API キー）を一通り触る
3. 幅 390px で `document.documentElement.scrollWidth` が 390 以下か

Playwright がある環境なら、`page.route('https://api.anthropic.com/**', ...)` で SSE を返すモックを作ると API キーなしで診断フローを確認できる。

## 経緯

- 2026-10-10: claude.ai 上で Artifact として作成。観点別問診票、自己評価、レーダー付きの診断結果。
- 同日: 観点 07「開発体制と工数」（開発タイプ・期間・メンバー・計画/実績工数・工数の使い道）を追加。ロードマップ取り込み（CSV / Excel / 画像）を追加。
- 同日: このリポジトリの `/diagnosis/` に配置し、API キー方式を追加して GitHub Pages で公開。スマホ幅の横はみ出しを修正。
- 実際の API キーでの診断はまだ未検証（モックでのみ確認済み）。

## 次の候補（未着手）

- 実キーでの診断品質と所要時間の確認、プロンプト調整
- 診断結果から不足情報を追加で質問する深掘り対話
- To-Be 設計への接続（第2段階）
- 公開・共有向けに、API キーを利用者に入れさせずサーバー経由（Vercel の API ルートなど）で呼ぶ構成
- 診断履歴の保存（直下アプリと同じ Supabase を使うかは要相談）
