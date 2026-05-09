-- ============================================================
-- AgriGrade MVP — Migration 003: prices_table
-- ============================================================
-- Dibuat: 2025
-- Versi schema: 1.0
--
-- CARA APPLY:
--   Paste seluruh isi file ini ke Supabase SQL Editor
--   (Dashboard → SQL Editor → New Query → Run)
--
-- PRASYARAT: Jalankan 001_assessments_table.sql dan
--   002_assessments_rls_indexes.sql terlebih dahulu.
--
-- CATATAN: Fungsi update_updated_at_column() dibuat dengan
--   CREATE OR REPLACE FUNCTION agar aman dijalankan setelah
--   migration lain yang mungkin sudah mendefinisikan fungsi ini.
-- ============================================================

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
-- Fungsi generik yang di-set ke NEW.updated_at = now() sebelum
-- setiap UPDATE. Digunakan oleh trigger prices_updated_at.
-- CREATE OR REPLACE digunakan agar aman jika fungsi sudah ada
-- dari migration sebelumnya.
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Trigger: prices_updated_at
-- Memanggil update_updated_at_column() secara otomatis sebelum
-- setiap operasi UPDATE pada prices_table, sehingga kolom
-- updated_at selalu mencerminkan waktu perubahan terakhir.
-- Requirements: 9.5
-- ============================================================
CREATE TRIGGER prices_updated_at
  BEFORE UPDATE ON prices_table
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Row Level Security (RLS)
-- ============================================================

-- Aktifkan RLS pada prices_table.
-- Requirements: 9.1–9.7
ALTER TABLE prices_table ENABLE ROW LEVEL SECURITY;

-- Policy read-only untuk semua pengguna (termasuk anonymous).
-- prices_table hanya perlu dibaca oleh Dashboard — tidak ada
-- operasi INSERT/UPDATE/DELETE dari sisi klien.
-- Requirements: 9.6, 9.7
CREATE POLICY "mvp_allow_read_prices"
  ON prices_table
  FOR SELECT
  USING (true);

-- ============================================================
-- Seed Data
-- Data harga awal untuk dua komoditas utama AgriGrade.
-- Harga dapat diperbarui langsung via Supabase Dashboard atau
-- SQL Editor tanpa mengubah kode aplikasi.
-- Requirements: 1.2, 1.3, 9.7
-- ============================================================
INSERT INTO prices_table (commodity_name, price_per_kg, unit) VALUES
  ('Vanili',  3500000, 'IDR'),
  ('Cengkeh',   85000, 'IDR');
