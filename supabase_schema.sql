-- supabase_schema.sql
-- Skema online Numisma (NUMISMA_GUIDE 0.7, Bagian 5.2).
-- Cara pakai: Supabase Dashboard -> SQL Editor -> New query -> tempel
-- seluruh isi file ini -> Run. Aman dijalankan ulang (IF NOT EXISTS) dan
-- aman dijalankan di atas skema lama (kolom baru ditambah lewat ALTER).
--
-- Tidak ada FOREIGN KEY di sini, dan itu disengaja: tanpa Supabase Auth
-- tidak ada tabel pengguna untuk dirujuk, dan koin/blok boleh tiba dalam
-- urutan apa saja saat sinkron (blok DELETE tetap ada walau koinnya sudah
-- dihapus). Hubungan antartabel bersifat logis lewat nilai yang sama:
--   accounts.email_hash = coins.user_key = chain_blocks.user_key
--   chain_blocks.coin_id = coins.id

-- Akun. TANPA email polos dan TANPA password polos.
create table if not exists accounts (
  email_hash text primary key,       -- SHA-256("numisma:" + email), kunci sinkron
  username text not null,            -- nama tampilan (bebas, tidak unik)
  password_hash text not null,       -- bcrypt
  created_at timestamptz not null
);

create table if not exists coins (
  id text primary key,
  user_key text not null,            -- = accounts.email_hash pemilik
  type text not null,
  country text not null,
  currency_code text not null,
  denomination double precision not null,
  year int,
  condition text,
  buy_price double precision,
  buy_currency text,
  notes_enc text,                    -- ciphertext AES; tidak terbuka di perangkat tanpa kunci lama
  ai_summary text,
  has_photo boolean not null default false,   -- ada foto di Storage
  created_at timestamptz not null,
  updated_at timestamptz not null
);
-- Untuk tabel coins yang sudah dibuat dengan skema lama.
alter table coins add column if not exists has_photo boolean not null default false;

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

-- Pencarian per pemilik saat unggah dan Pulihkan.
create index if not exists idx_coins_user_key on coins(user_key);
create index if not exists idx_chain_blocks_user_key on chain_blocks(user_key, idx);

-- Spot kolektor dibuang dari rencana. Bila tabel lama masih ada di
-- Supabase, hapus lewat perintah terpisah (lihat catatan di chat).

-- Akses untuk anon key (kunci yang tertanam di aplikasi).
-- PERMISIF dan hanya untuk demo: siapa pun yang punya anon key bisa
-- baca/tulis. Ini keterbatasan keamanan yang dicatat di laporan
-- (Bagian 1.6). Hapus/ketatkan setelah penilaian selesai.
alter table accounts enable row level security;
alter table coins enable row level security;
alter table chain_blocks enable row level security;

drop policy if exists "demo_accounts_all" on accounts;
create policy "demo_accounts_all" on accounts
  for all to anon using (true) with check (true);

drop policy if exists "demo_coins_all" on coins;
create policy "demo_coins_all" on coins
  for all to anon using (true) with check (true);

drop policy if exists "demo_chain_blocks_all" on chain_blocks;
create policy "demo_chain_blocks_all" on chain_blocks
  for all to anon using (true) with check (true);

-- Storage: bucket privat untuk foto koin, objek bernama
-- "{user_key}/{coin_id}.jpg". Unggah dengan upsert butuh policy
-- insert, update, dan select.
insert into storage.buckets (id, name, public)
values ('coin-photos', 'coin-photos', false)
on conflict (id) do nothing;

drop policy if exists "demo_coin_photos_all" on storage.objects;
create policy "demo_coin_photos_all" on storage.objects
  for all to anon
  using (bucket_id = 'coin-photos')
  with check (bucket_id = 'coin-photos');
