-- supabase_reset_v6.sql
-- SEKALI JALAN, bersamaan dengan DB lokal v6 (harga beli dan mata uang beli
-- dibuang dari koin). Cara pakai: Supabase Dashboard -> SQL Editor -> New
-- query -> tempel -> Run.
--
-- Kenapa harus dikosongkan: kedua kolom itu ikut dalam snapshot hash Jejak
-- Catatan (data_hash). Setelah snapshot berubah, blok lama tidak lagi cocok
-- dengan koinnya, dan blok yang sudah dibuat tidak boleh diubah. Bila data
-- online tidak dikosongkan, login di HP yang bersih akan memulihkan rantai
-- lama lalu Verifikasi melaporkan "berubah".
--
-- Yang dihapus: semua koin dan blok. Tabel accounts (akun) TIDAK disentuh,
-- jadi login tetap berjalan. Foto di Storage tidak dihapus lewat SQL
-- (hapus lewat Dashboard -> Storage -> coin-photos bila ingin bersih; foto
-- yatim tidak berbahaya).
--
-- Transaksi di blockchain Sepolia tidak ikut terhapus (memang tidak bisa),
-- tetapi tidak mengganggu rantai baru.

delete from chain_blocks;
delete from coins;

alter table coins drop column if exists buy_price;
alter table coins drop column if exists buy_currency;
