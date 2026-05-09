/**
 * AgriGrade Database Types
 * Tipe-tipe TypeScript yang merepresentasikan skema database Supabase.
 * Requirements: 5.1–5.18, 9.1–9.5
 */

/**
 * Klasifikasi kualitas komoditas.
 * 'A' = kualitas premium, 'B' = kualitas standar.
 */
export type Grade = 'A' | 'B'

/**
 * Satu record hasil scan komoditas yang tersimpan di Assessments_Table.
 * Memiliki 14 kolom sesuai skema database.
 * Requirements: 5.1–5.18
 */
export interface Assessment {
  /** UUID primary key, di-generate otomatis oleh Supabase. Requirements: 5.1 */
  id: string

  /** URL gambar komoditas di Supabase Storage. Bernilai '[DELETED]' jika gambar telah dihapus oleh cleanup job. Requirements: 5.2 */
  image_url: string

  /** Hasil penilaian kualitas: 'A' atau 'B'. Requirements: 5.3 */
  grade: Grade

  /** Nilai kepercayaan analisis AI, angka desimal antara 0 dan 1. Requirements: 5.4 */
  confidence: number

  /** Status penyakit komoditas: true jika terdeteksi penyakit. Requirements: 5.5 */
  disease: boolean

  /** Identifikasi petani. Bernilai statis 'farmer_mvp_001' pada fase MVP. Requirements: 5.6 */
  farmer_id: string

  /** Timestamp saat record dibuat, di-set otomatis oleh Supabase. Requirements: 5.7 */
  created_at: string

  /** Koordinat GPS lintang lokasi scan. Null jika GPS tidak tersedia atau ditolak. Requirements: 5.10 */
  latitude: number | null

  /** Koordinat GPS bujur lokasi scan. Null jika GPS tidak tersedia atau ditolak. Requirements: 5.11 */
  longitude: number | null

  /** Kode Batch ID unik format AG-{YYYYMMDD}-{6chars}. Null sebelum di-generate. Requirements: 5.12 */
  batch_id: string | null

  /** Status verifikasi manual oleh admin pabrik. Default false. Requirements: 5.13 */
  is_verified: boolean

  /** Timestamp kapan gambar dihapus oleh cleanup job. Null jika gambar masih ada. Requirements: 6.11 */
  image_deleted_at: string | null

  /** Base64 thumbnail 8x8px untuk blur-up placeholder di Dashboard. Null jika belum di-generate. Requirements: 5.18 */
  blur_data_url: string | null

  /** True jika assessment disubmit tanpa data GPS valid (GPS gagal atau ditolak). Requirements: 5.17 */
  is_mock_location: boolean
}

/**
 * Tipe untuk INSERT record Assessment baru ke database.
 * Mengecualikan kolom yang di-generate otomatis oleh Supabase:
 * - id: di-generate sebagai UUID oleh database
 * - created_at: di-set otomatis ke waktu saat INSERT
 * - is_verified: default false, tidak perlu disertakan saat INSERT
 *
 * Catatan: is_mock_location harus disertakan saat INSERT.
 * Requirements: 5.1–5.18
 */
export type AssessmentInsert = Omit<Assessment, 'id' | 'created_at' | 'is_verified'>

/**
 * Harga komoditas yang tersimpan di Prices_Table.
 * Digunakan sebagai sumber data harga dinamis di Dashboard.
 * Requirements: 9.1–9.5
 */
export interface Price {
  /** UUID primary key, di-generate otomatis oleh Supabase. Requirements: 9.1 */
  id: string

  /** Nama komoditas, contoh: 'Vanili', 'Cengkeh'. Requirements: 9.2 */
  commodity_name: string

  /** Harga komoditas per kilogram dalam satuan yang ditentukan oleh kolom unit. Requirements: 9.3 */
  price_per_kg: number

  /** Satuan mata uang harga. Default 'IDR'. Requirements: 9.4 */
  unit: string

  /** Timestamp saat record terakhir diperbarui, di-update otomatis via trigger database. Requirements: 9.5 */
  updated_at: string
}

/**
 * Data Assessment yang disimpan sementara di IndexedDB Offline_Queue
 * saat koneksi internet tidak tersedia.
 * Akan di-sync ke Supabase saat koneksi pulih via Background Sync.
 * Requirements: 8.4
 */
export interface OfflineAssessmentData {
  /** Hasil penilaian kualitas: 'A' atau 'B'. */
  grade: Grade

  /** Nilai kepercayaan analisis AI, angka desimal antara 0 dan 1. */
  confidence: number

  /** Status penyakit komoditas: true jika terdeteksi penyakit. */
  disease: boolean

  /** Kode Batch ID unik yang di-generate saat analisis. */
  batch_id: string

  /** URL gambar komoditas (bisa berupa object URL lokal saat offline). */
  image_url: string

  /** Koordinat GPS lintang. Null jika GPS tidak tersedia. */
  latitude: number | null

  /** Koordinat GPS bujur. Null jika GPS tidak tersedia. */
  longitude: number | null

  /** Identifikasi petani. */
  farmer_id: string

  /** Timestamp ISO 8601 saat data di-enqueue ke Offline_Queue. */
  queued_at: string
}

/**
 * Tipe Root Database untuk Supabase.
 * Menggabungkan semua interface tabel menjadi satu struktur yang dikenali oleh @supabase/ssr.
 */
export interface Database {
  public: {
    Tables: {
      assessments_table: {
        Row: Assessment
        Insert: AssessmentInsert
        Update: Partial<Omit<Assessment, 'id'>>
      }
      prices_table: {
        Row: Price
        Insert: Omit<Price, 'id' | 'updated_at'>
        Update: Partial<Omit<Price, 'id' | 'updated_at'>>
      }
    }
  }
}