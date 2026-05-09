-- ============================================================
-- AgriGrade MVP — Complete Database Schema
-- ============================================================
-- Dibuat: 2025
-- Versi schema: 1.0
--
-- CARA APPLY:
--   Paste seluruh isi file ini ke Supabase SQL Editor
--   (Dashboard → SQL Editor → New Query → Run)
--
--   File ini menggabungkan semua DDL dari migration 001–003:
--     - CREATE TABLE assessments_table (14 kolom)
--     - RLS policies dan indexes untuk assessments_table
--     - CREATE TABLE prices_table + trigger + seed data
--
-- DISASTER RECOVERY:
--   Jika project Supabase dihapus atau akun berganti, seluruh
--   struktur database dapat dibangun ulang dalam hitungan detik
--   dengan menjalankan file ini di project Supabase baru.
-- ============================================================

-- ============================================================
-- Assessments_Table
-- Menyimpan setiap hasil scan komoditas oleh petani.
-- 14 kolom sesuai Requirements 5.1–5.18
-- ============================================================
CREATE TABLE assessments_table (
  -- UUID primary key, di-generate otomatis oleh database. Requirements: 5.1
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),

  -- URL gambar komoditas di Supabase Storage. Bernilai '[DELETED]' jika gambar telah dihapus. Requirements: 5.2
  image_url        TEXT        NOT NULL,

  -- Hasil penilaian kualitas: 'A' (premium) atau 'B' (standar). Requirements: 5.3
  grade            TEXT        NOT NULL CHECK (grade IN ('A', 'B')),

  -- Nilai kepercayaan analisis AI, angka desimal antara 0 dan 1. Requirements: 5.4
  confidence       FLOAT       NOT NULL CHECK (confidence >= 0 AND confidence <= 1),

  -- Status penyakit komoditas: true jika terdeteksi penyakit. Requirements: 5.5
  disease          BOOLEAN     NOT NULL DEFAULT false,

  -- Identifikasi petani. Bernilai statis 'farmer_mvp_001' pada fase MVP. Requirements: 5.6
  farmer_id        TEXT        NOT NULL,

  -- Timestamp saat record dibuat, di-set otomatis oleh database. Requirements: 5.7
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Koordinat GPS lintang lokasi scan. NULL jika GPS tidak tersedia atau ditolak. Requirements: 5.10
  latitude         FLOAT,

  -- Koordinat GPS bujur lokasi scan. NULL jika GPS tidak tersedia atau ditolak. Requirements: 5.11
  longitude        FLOAT,

  -- Kode Batch ID unik format AG-{YYYYMMDD}-{6chars}. NULL sebelum di-generate. Requirements: 5.12, 7.8
  batch_id         TEXT        UNIQUE,

  -- Status verifikasi manual oleh admin pabrik. Default false. Requirements: 5.13
  is_verified      BOOLEAN     NOT NULL DEFAULT false,

  -- Timestamp kapan gambar dihapus oleh cleanup job. NULL = gambar masih ada. Requirements: 6.11
  image_deleted_at TIMESTAMPTZ,

  -- Base64 thumbnail 8x8px untuk blur-up placeholder di Dashboard. NULL = belum di-generate. Requirements: 5.18
  blur_data_url    TEXT,

  -- true jika petani melanjutkan scan tanpa data GPS valid (GPS gagal atau ditolak). Requirements: 5.17
  is_mock_location BOOLEAN     NOT NULL DEFAULT false
);

-- ============================================================
-- Row Level Security (RLS) — assessments_table
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
-- Indexes — assessments_table
-- ============================================================

-- Index komposit untuk query riwayat scan per petani di Dashboard.
-- Mendukung: SELECT * FROM assessments_table
--            WHERE farmer_id = ? ORDER BY created_at DESC
CREATE INDEX idx_assessments_farmer_id_created_at
  ON assessments_table (farmer_id, created_at DESC);

-- Index komposit untuk query daftar assessment belum diverifikasi
-- di halaman Admin (/admin/verify).
-- Mendukung: SELECT * FROM assessments_table
--            WHERE is_verified = false ORDER BY created_at DESC
CREATE INDEX idx_assessments_is_verified
  ON assessments_table (is_verified, created_at DESC);

-- ============================================================
-- Prices_Table
-- Menyimpan harga komoditas terkini sebagai sumber data dinamis
-- untuk Dashboard. Harga dapat diperbarui tanpa mengubah kode
-- aplikasi. Requirements: 9.1–9.7
-- ============================================================
CREATE TABLE prices_table (
  -- UUID primary key, di-generate otomatis oleh database. Requirements: 9.1
  id             UUID          PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Nama komoditas, contoh: 'Vanili', 'Cengkeh'. Requirements: 9.2
  commodity_name TEXT          NOT NULL,

  -- Harga komoditas per kilogram dalam satuan yang ditentukan kolom unit. Requirements: 9.3
  price_per_kg   NUMERIC(12,2) NOT NULL,

  -- Satuan mata uang harga. Default 'IDR'. Requirements: 9.4
  unit           TEXT          NOT NULL DEFAULT 'IDR',

  -- Timestamp saat record terakhir diperbarui, di-update otomatis via trigger. Requirements: 9.5
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ============================================================
-- Trigger Function: update_updated_at_column()
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: auto-update updated_at saat row di-UPDATE
CREATE TRIGGER prices_updated_at
  BEFORE UPDATE ON prices_table
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Row Level Security (RLS) — prices_table
-- ============================================================
ALTER TABLE prices_table ENABLE ROW LEVEL SECURITY;

-- Policy read-only untuk semua pengguna (termasuk anonymous).
-- Requirements: 9.6, 9.7
CREATE POLICY "mvp_allow_read_prices"
  ON prices_table
  FOR SELECT
  USING (true);

-- ============================================================
-- Seed Data — prices_table
-- ============================================================
INSERT INTO prices_table (commodity_name, price_per_kg, unit) VALUES
  ('Vanili',  3500000, 'IDR'),
  ('Cengkeh',   85000, 'IDR');
