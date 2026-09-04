// connpass API v2 から PdM/PM関連イベントを検索し、events.json を更新する。
// GitHub Actions から1日1回、または手動で実行する想定。
//
// 必要な環境変数:
//   CONNPASS_API_KEY - connpassの個人・コミュニティ向けAPI利用申請で発行されるキー
//                        https://help.connpass.com/api/ から申請（審査あり、発行まで1週間程度）
//
// キー未設定の場合はエラーで終了せず、既存の events.json をそのまま残す（サイトを壊さないため）。

const fs = require("fs");
const path = require("path");

const API_KEY = process.env.CONNPASS_API_KEY;
const OUTPUT_PATH = path.join(__dirname, "..", "events.json");

// OR検索したいキーワード（PdM/PM関連）。connpassの keyword_or は指定した語のいずれかを含むイベントを返す。
const KEYWORDS = ["プロダクトマネージャー", "プロダクトマネジメント", "PdM", "プロダクトオーナー", "PM"];

async function fetchPage(start) {
  const params = new URLSearchParams({
    keyword_or: KEYWORDS.join(","),
    order: "2", // 開催日降順（新しい開催日が先）ではなく昇順にしたい場合は "1"
    count: "100",
    start: String(start),
  });
  const url = `https://connpass.com/api/v2/events/?${params.toString()}`;
  const res = await fetch(url, {
    headers: {
      "X-API-Key": API_KEY,
      "User-Agent": "pdm-skill-quest-event-calendar/1.0 (+https://satoshikubo0821.github.io/PdM/)",
    },
  });
  if (!res.ok) {
    throw new Error(`connpass API error: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

async function main() {
  if (!API_KEY) {
    console.log("CONNPASS_API_KEY が未設定のため、events.json は更新せずに終了します。");
    return;
  }

  const now = new Date();
  const futureLimit = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000); // 90日先まで

  let allEvents = [];
  let start = 1;
  const PAGE_SIZE = 100;

  try {
    while (true) {
      const data = await fetchPage(start);
      const events = data.events || [];
      allEvents = allEvents.concat(events);
      if (events.length < PAGE_SIZE || allEvents.length >= 300) break; // 安全のため上限300件
      start += PAGE_SIZE;
      await new Promise((r) => setTimeout(r, 1100)); // レート制限（1秒1リクエスト）に配慮
    }
  } catch (e) {
    console.error("connpass APIの取得に失敗しました:", e.message);
    console.log("既存の events.json は変更せず終了します。");
    return;
  }

  // 開催予定（未来）かつ90日以内のイベントのみに絞り、開催日時でソート
  const upcoming = allEvents
    .filter((ev) => {
      const started = new Date(ev.started_at);
      return started >= now && started <= futureLimit;
    })
    .sort((a, b) => new Date(a.started_at) - new Date(b.started_at))
    .map((ev) => ({
      title: ev.title,
      url: ev.url,
      startedAt: ev.started_at,
      endedAt: ev.ended_at,
      place: ev.address || (ev.event_type === "online" ? "オンライン開催" : "未定"),
      eventType: ev.event_type,
      organizer: (ev.group && ev.group.title) || null,
      accepted: ev.accepted,
      limit: ev.limit,
      catchphrase: ev.catch || "",
      source: "connpass",
    }));

  const payload = {
    updatedAt: now.toISOString(),
    count: upcoming.length,
    events: upcoming,
  };

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(payload, null, 2), "utf8");
  console.log(`events.json を更新しました。件数: ${upcoming.length}`);
}

main().catch((e) => {
  console.error("予期しないエラー:", e);
  process.exit(0); // ワークフロー全体を失敗させず、既存ファイルを保持する
});
