-- ============================================================
-- AgriGrade MVP — Migration 002: RLS & Indexes untuk assessments_table
-- ============================================================
-- Dibuat: 2025
-- Versi schema: 1.0
--
-- CARA APPLY:
--   Paste seluruh isi file ini ke Supabase SQL Editor
--   (Dashboard → SQL Editor → New Query → Run)
--
-- PRASYARAT: Jalankan 001_assessments_table.sql terlebih dahulu
--   sebelum menjalankan migration ini.
-- ============================================================

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

-- Aktifkan RLS pada assessments_table.
-- RLS harus di-enable sejak awal, bahkan sebelum autentikasi penuh
-- diimplementasikan, agar tabel tidak pernah berjalan tanpa proteksi.
-- Requirements: 5.14
ALTER TABLE assessments_table ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- ⚠️  PERINGATAN MVP — POLICY SEMENTARA ⚠️
-- ============================================================
-- Policy di bawah ini mengizinkan SEMUA operasi (SELECT, INSERT,
-- UPDATE, DELETE) untuk SEMUA pengguna tanpa autentikasi.
--
-- Policy ini HANYA untuk fase development MVP dan HARUS DIGANTI
-- sebelum aplikasi diluncurkan ke production dengan pengguna nyata.
--
-- SAAT SUPABASE AUTH DIIMPLEMENTASIKAN, hapus policy ini dan
-- ganti dengan policy berbasis farmer_id berikut:
--
--   DROP POLICY "mvp_allow_all_assessments" ON assessments_table;
--
--   CREATE POLICY "farmer_own_data" ON assessments_table
--     FOR ALL
--     USING (auth.uid()::text = farmer_id)
--     WITH CHECK (auth.uid()::text = farmer_id);
--
-- Policy baru tersebut memastikan setiap petani hanya dapat
-- membaca dan menulis data miliknya sendiri.
-- Requirements: 5.15, 5.16
-- ============================================================
CREATE POLICY "mvp_allow_all_assessments"
  ON assessments_table
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- Indexes
-- ============================================================

-- Index komposit untuk query riwayat scan per petani di Dashboard.
-- Mendukung: SELECT * FROM assessments_table
--            WHERE farmer_id = ? ORDER BY created_at DESC
-- Requirements: 5.14
CREATE INDEX idx_assessments_farmer_id_created_at
  ON assessments_table (farmer_id, created_at DESC);

-- Index komposit untuk query daftar assessment belum diverifikasi
-- di halaman Admin (/admin/verify).
-- Mendukung: SELECT * FROM assessments_table
--            WHERE is_verified = false ORDER BY created_at DESC
-- Requirements: 5.13
CREATE INDEX idx_assessments_is_verified
  ON assessments_table (is_verified, created_at DESC);
