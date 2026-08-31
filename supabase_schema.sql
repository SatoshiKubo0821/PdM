-- ============================================================
-- PdMスキルレーダー / Supabase セットアップ用SQL
-- Supabaseダッシュボード → SQL Editor に貼り付けて実行してください。
-- ============================================================

-- 1) 診断結果を保存するテーブル（1回の診断完了ごとに1行 = 履歴になる）
create table if not exists public.diagnoses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  answers jsonb not null,          -- 全回答（スキル名:スコア）
  mbti text,                       -- 選択されたMBTI（任意）
  toeic int,                       -- TOEICスコア（任意）
  certifications text,             -- 保有資格（任意）
  nickname text,                   -- ニックネーム（任意）
  experience_years numeric(4,1),   -- PdM経験年数（任意）
  overall_avg numeric(4,2) not null,
  pdm_type text not null,          -- tech / bizdev / pmm / general
  seniority text not null,         -- junior / middle / senior
  hensachi int not null
);

-- 既存プロジェクト用：すでにテーブルがある場合でも安全に追加カラムを反映する
alter table public.diagnoses add column if not exists nickname text;
alter table public.diagnoses add column if not exists experience_years numeric(4,1);

-- 2) Row Level Security（自分の行しか読み書きできないようにする）
alter table public.diagnoses enable row level security;

drop policy if exists "select own diagnoses" on public.diagnoses;
create policy "select own diagnoses"
  on public.diagnoses for select
  using (auth.uid() = user_id);

drop policy if exists "insert own diagnoses" on public.diagnoses;
create policy "insert own diagnoses"
  on public.diagnoses for insert
  with check (auth.uid() = user_id);

drop policy if exists "delete own diagnoses" on public.diagnoses;
create policy "delete own diagnoses"
  on public.diagnoses for delete
  using (auth.uid() = user_id);

-- 3) 運営者向け：全ユーザーの回答を「集計値のみ」返す関数
--    個々のユーザーの生データは一切返さず、件数・平均・分布のみを返すため、
--    anonキー（publishable key）から誰でも呼び出しても安全な設計にしている。
create or replace function public.get_aggregate_stats()
returns json
language sql
security definer
set search_path = public
as $$
  select json_build_object(
    'total_diagnoses', (select count(*) from public.diagnoses),
    'avg_overall', (select round(avg(overall_avg),2) from public.diagnoses),
    'avg_hensachi', (select round(avg(hensachi),1) from public.diagnoses),
    'by_type', (
      select coalesce(json_agg(json_build_object('pdm_type', pdm_type, 'count', cnt)), '[]'::json)
      from (select pdm_type, count(*) cnt from public.diagnoses group by pdm_type order by cnt desc) t
    ),
    'by_seniority', (
      select coalesce(json_agg(json_build_object('seniority', seniority, 'count', cnt)), '[]'::json)
      from (select seniority, count(*) cnt from public.diagnoses group by seniority order by cnt desc) t
    ),
    'mbti_distribution', (
      select coalesce(json_agg(json_build_object('mbti', mbti, 'count', cnt)), '[]'::json)
      from (select mbti, count(*) cnt from public.diagnoses where mbti is not null group by mbti order by cnt desc) t
    )
  );
$$;

grant execute on function public.get_aggregate_stats() to anon, authenticated;

-- 4) （任意）30日以上放置された匿名ユーザーの掃除用クエリ。
--    Supabaseダッシュボードから定期的に手動実行するか、pg_cronで自動化できます。
-- delete from auth.users
--   where is_anonymous = true
--   and created_at < now() - interval '30 days';

-- ============================================================
-- 実行後の確認事項（Supabaseダッシュボード側）：
-- 1. Authentication → Providers → Anonymous Sign-Ins を有効化
-- 2. Authentication → Providers → Email を有効化（Confirm email をON推奨）
-- 3. Authentication → URL Configuration → Site URL に公開後のドメインを設定
-- 4. Project Settings → API から Project URL と anon / publishable key を控えて
--    pdm-skill-radar.html の SUPABASE_URL / SUPABASE_ANON_KEY に設定
-- ============================================================
