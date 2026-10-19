-- supabase_schema.sql
-- Skema tabel online Numisma (NUMISMA_GUIDE Bagian 5.2).
-- Cara pakai: Supabase Dashboard -> SQL Editor -> New query -> tempel
-- seluruh isi file ini -> Run. Aman dijalankan ulang (IF NOT EXISTS).

create table if not exists coins (
  id text primary key,
  user_key text not null,            -- = username (tanpa Supabase Auth)
  type text not null,
  country text not null,
  currency_code text not null,
  denomination double precision not null,
  year int,
  condition text,
  buy_price double precision,
  buy_currency text,
  notes_enc text,
  ai_summary text,
  created_at timestamptz not null,
  updated_at timestamptz not null
);

create table if not exists chain_blocks (
  id text primary key,               -- "{user_key}:{idx}"
  user_key text not null,
  idx int not null,
  ts timestamptz not null,
  coin_id text,
  action text not null,
  data_hash text not null,
  photo_hash text,
  photo_source text,
  prev_hash text not null,
  nonce bigint not null,
  hash text not null
);

create table if not exists collector_spots (
  id bigint generated always as identity primary key,
  name text not null,
  city text,
  lat double precision not null,
  lng double precision not null,
  type text,                         -- museum, bank, toko antik, pasar, komunitas
  note text,
  verified boolean not null default false
);

-- Akses untuk anon key (kunci yang tertanam di aplikasi).
-- PERMISIF dan hanya untuk demo: siapa pun yang punya anon key bisa
-- baca/tulis. Ini keterbatasan keamanan yang dicatat di laporan
-- (Bagian 1.6). Hapus/ketatkan setelah penilaian selesai.
alter table coins enable row level security;
alter table chain_blocks enable row level security;
alter table collector_spots enable row level security;

drop policy if exists "demo_coins_all" on coins;
create policy "demo_coins_all" on coins
  for all to anon using (true) with check (true);

drop policy if exists "demo_chain_blocks_all" on chain_blocks;
create policy "demo_chain_blocks_all" on chain_blocks
  for all to anon using (true) with check (true);

-- Spot kolektor: aplikasi hanya membaca. Isi datanya lewat Table Editor
-- di dashboard (dashboard tidak terkena RLS).
drop policy if exists "demo_spots_read" on collector_spots;
create policy "demo_spots_read" on collector_spots
  for select to anon using (true);
