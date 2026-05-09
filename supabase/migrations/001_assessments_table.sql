-- ============================================================
-- AgriGrade MVP — Migration 001: assessments_table
-- ============================================================
-- Dibuat: 2025
-- Versi schema: 1.0
--
-- CARA APPLY:
--   Paste seluruh isi file ini ke Supabase SQL Editor
--   (Dashboard → SQL Editor → New Query → Run)
--
-- CATATAN: File ini hanya berisi CREATE TABLE untuk assessments_table.
--   - RLS policies dan indexes: lihat 002_assessments_rls_indexes.sql
--   - prices_table: lihat 003_prices_table.sql
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
