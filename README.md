# 🌿 AgriGrade MVP

> **Platform kurasi hasil tani berbasis mobile-first** yang membantu petani Vanili dan Cengkeh melakukan penilaian kualitas komoditas secara mandiri di lapangan — menyuplai data terverifikasi ke **Sima Arome**, perusahaan fragrance terkemuka.

---

## 🎯 Mengapa AgriGrade?

Sima Arome membutuhkan bahan baku berkualitas tinggi yang **tertelusuri asal-usulnya**. Selama ini, proses grading dilakukan manual di pabrik — lambat, tidak skalabel, dan tidak memberikan data lokasi panen.

AgriGrade membalik alurnya: **petani scan di kebun, data langsung masuk ke sistem Sima Arome** lengkap dengan koordinat GPS, foto terkompresi, dan kode traceability unik per karung. Admin pabrik tinggal verifikasi dari dashboard.

---

## ✨ Key Features

| Fitur | Deskripsi |
|---|---|
| 📷 **Scan Mandiri** | Kamera belakang HP via `capture="environment"` — tidak perlu aplikasi native |
| 🤖 **AI Grade Simulation** | Server-side analyzer dengan delay 2 detik, menghasilkan Grade A/B + confidence + disease status |
| 📦 **Batch ID Traceability** | Kode unik `AG-{YYYYMMDD}-{6chars}` per karung — admin pabrik tinggal scan kode untuk cocokkan data |
| 📡 **Offline-First** | IndexedDB queue + Background Sync — data tidak hilang meski sinyal putus di kebun |
| ⚡ **Circuit Breaker** | Timeout 10 detik otomatis fallback ke offline queue — menangani *zombie connection* |
| 🗜️ **Image Compression** | Canvas API iterative reduction hingga ≤500KB — hemat kuota petani di jaringan 3G/Edge |
| 🔒 **Signed URLs** | Private bucket Supabase Storage + TTL 1 jam — mencegah URL enumeration attack |
| 🌍 **GPS Anti-Fraud** | Koordinat diambil real-time saat tombol ditekan, bukan dari cache — data lokasi terjamin otentik |
| 📸 **EXIF Validation** | Deteksi foto lama (>24 jam) dari metadata — warning non-blocking untuk petani |
| 📊 **Export PDF/CSV** | Laporan scan dan riwayat lengkap — petani bisa cetak bukti kualitas untuk negosiasi harga |
| 🏭 **Admin Verify Panel** | Dashboard pabrik Sima Arome untuk verifikasi grade AI + pencarian global by Batch ID |
| 📲 **PWA Installable** | Bisa diinstal di home screen HP petani — tampil seperti aplikasi native |

---

## 🛠️ Tech Stack

### Mengapa Next.js 16 + Tailwind v4?

Petani menggunakan HP mid-range dengan RAM terbatas dan koneksi 3G/Edge yang tidak stabil. Pilihan stack ini bukan sekadar tren — ada alasan teknis konkret:

| Teknologi | Alasan Dipilih |
|---|---|
| **Next.js 16 App Router** | React Server Components mengurangi JavaScript yang dikirim ke browser — halaman Dashboard di-render di server, petani hanya download HTML yang sudah jadi |
| **Tailwind CSS v4** | Zero runtime CSS — tidak ada overhead JavaScript untuk styling, performa di HP low-end lebih baik |
| **Supabase** | PostgreSQL managed + Storage + RLS built-in — tidak perlu setup backend terpisah untuk MVP |
| **Shadcn UI** | Komponen di-copy ke project (bukan dependency) — bundle size terkontrol, tidak ada bloat |
| **IndexedDB via `idb`** | Persistent offline storage yang bekerja di background — data scan tidak hilang meski browser ditutup |
| **Canvas API** | Image compression native browser — tidak perlu library tambahan, tidak ada network request |
| **Vibration API** | Haptic feedback untuk konfirmasi scan — petani bisa rasakan status tanpa menatap layar di bawah terik matahari |

```
Framework    : Next.js 16 (App Router) + React 19
Styling      : Tailwind CSS v4
UI Components: Shadcn UI
Database     : Supabase (PostgreSQL + Storage)
Validation   : Zod
Testing      : Vitest + fast-check (property-based testing)
Monitoring   : Vercel Analytics + Speed Insights
CI/CD        : GitHub Actions → Vercel
```

---

## 🏗️ Architecture Overview

```
Browser (Mobile)
├── React UI (Client Components)
├── Service Worker (sw.js) ──── Cache statis + Background Sync
└── IndexedDB (Offline_Queue) ── Data pending saat offline

Next.js 16 App Router (Server)
├── React Server Components ─── Dashboard, data fetching
├── Server Actions ─────────── analyzeImage, saveAssessment, admin ops
└── Middleware ──────────────── Proteksi /admin/* via httpOnly cookie

Supabase
├── PostgreSQL ──────────────── assessments_table + prices_table
└── Storage (Private) ───────── commodity-images bucket
```

**Data flow scan komoditas:**
```
Petani pilih foto
  → EXIF validation (client)
  → Image compression ≤500KB (Canvas API)
  → Tekan "Analisis Sekarang"
  → GPS getCurrentPosition() real-time
  → analyzeWithTimeout() [circuit breaker 10s]
      ├── Online  → Server Action → Supabase → /result
      └── Offline → IndexedDB Queue → /result (local) → Background Sync saat online
```

---

## 🗄️ Database Schema

### `assessments_table`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | UUID PK | Auto-generated |
| `image_url` | TEXT | URL gambar atau `'[DELETED]'` jika sudah cleanup |
| `grade` | TEXT | `'A'` atau `'B'` |
| `confidence` | FLOAT | Nilai kepercayaan AI [0.80–0.99] |
| `disease` | BOOLEAN | Status penyakit komoditas |
| `farmer_id` | TEXT | ID petani (MVP: `farmer_mvp_001`) |
| `created_at` | TIMESTAMPTZ | Auto-set saat INSERT |
| `latitude` | FLOAT? | Koordinat GPS lintang |
| `longitude` | FLOAT? | Koordinat GPS bujur |
| `batch_id` | TEXT UNIQUE? | Format `AG-{YYYYMMDD}-{6chars}` |
| `is_verified` | BOOLEAN | Status verifikasi admin pabrik |
| `image_deleted_at` | TIMESTAMPTZ? | Diisi cleanup job (>3 bulan) |
| `blur_data_url` | TEXT? | Base64 8x8px untuk blur-up placeholder |
| `is_mock_location` | BOOLEAN | `true` jika GPS gagal/ditolak saat scan |

### `prices_table`

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | UUID PK | Auto-generated |
| `commodity_name` | TEXT | Contoh: `'Vanili'`, `'Cengkeh'` |
| `price_per_kg` | NUMERIC(12,2) | Harga per kilogram |
| `unit` | TEXT | Default `'IDR'` |
| `updated_at` | TIMESTAMPTZ | Auto-update via trigger |

> **Seed data:** Vanili Rp 3.500.000/kg · Cengkeh Rp 85.000/kg

---

## ✅ Correctness Properties (P01–P13)

Aplikasi ini divalidasi dengan **property-based testing** menggunakan `fast-check` (min. 100 iterasi per property). Setiap property adalah pernyataan formal yang harus berlaku untuk **semua** input valid.

| ID | Property | Validates |
|---|---|---|
| **P01** | Assessment list selalu terurut descending by `created_at` | REQ-01 |
| **P02** | AI Analyzer: `grade ∈ {'A','B'}`, `confidence ∈ [0.80,0.99]`, `disease ∈ boolean` | REQ-03 |
| **P03** | Batch ID selalu cocok regex `^AG-\d{8}-[A-Z0-9]{6}$` | REQ-07 |
| **P04** | Batch ID unik — tidak ada duplikat dalam 1000 pemanggilan | REQ-07 |
| **P05** | `compressImage()` mempertahankan aspect ratio (toleransi ±0.01) | REQ-06 |
| **P06** | `compressImage()` menghasilkan file ≤ 500KB untuk input apapun | REQ-06 |
| **P07** | `isPhotoTooOld()` return `true` jika dan hanya jika selisih > 24 jam | REQ-02 |
| **P08** | Confidence ditampilkan sebagai `Math.round(confidence * 100) + '%'` | REQ-04 |
| **P09** | `GradeBadge`: grade A → CSS green, grade B → CSS yellow (konsisten) | REQ-04 |
| **P10** | Offline queue round-trip: data yang di-enqueue identik dengan yang di-dequeue | REQ-08 |
| **P11** | `verifyAdminPassword()`: hanya `ADMIN_PASSWORD` yang return `true` | REQ-10 |
| **P12** | GPS coords yang dikirim ke Server Action selalu dari `getCurrentPosition()` terbaru | REQ-02 |
| **P13** | `searchAssessmentByBatchId()`: exact match atau `null` — tidak boleh return record berbeda | REQ-07 |

---

## 🚀 Installation Guide

### Prerequisites

- Node.js 20+
- Akun [Supabase](https://supabase.com) (free tier cukup untuk MVP)
- Git

### 1. Clone & Install

```bash
git clone https://github.com/your-username/agrigrade.git
cd agrigrade
npm install
```

### 2. Setup Environment Variables

```bash
cp .env.example .env.local
```

Isi `.env.local` dengan nilai dari Supabase Dashboard → Project Settings → API:

```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
ADMIN_PASSWORD=your-secure-admin-password
```

> ⚠️ `ADMIN_PASSWORD` **tidak boleh** menggunakan prefix `NEXT_PUBLIC_` — ini server-only secret.

### 3. Setup Database

Buka **Supabase Dashboard → SQL Editor**, paste isi file berikut dan jalankan:

```
supabase/migrations/schema.sql
```

File ini berisi seluruh DDL: kedua tabel, RLS policies, indexes, trigger `updated_at`, dan seed data harga komoditas.

### 4. Setup Storage

Di Supabase Dashboard → Storage:
- Buat bucket baru bernama `commodity-images`
- Set visibility ke **Private**

### 5. Run Development Server

```bash
npm run dev
```

Buka [http://localhost:3000](http://localhost:3000) di browser.

> 💡 **Untuk test PWA & Haptic Feedback di HP fisik:** gunakan VS Code Port Forwarding (panel Ports → Forward 3000 → set Public) untuk mendapatkan URL HTTPS yang bisa dibuka di HP. Service Worker dan Camera API membutuhkan HTTPS.

### 6. Run Tests

```bash
# Single run (untuk CI)
npm run test:run

# Watch mode (untuk development)
npm test

# Dengan coverage report
npm run test:coverage
```

---

## 📁 Project Structure

```
agrigrade/
├── app/
│   ├── page.tsx              # Dashboard (Server Component)
│   ├── scan/page.tsx         # Camera Page (Client Component)
│   ├── result/page.tsx       # Result Page (Client Component)
│   ├── admin/
│   │   ├── login/page.tsx    # Admin Login
│   │   └── verify/page.tsx   # Admin Verify Dashboard
│   ├── actions/              # Server Actions (Zod-validated)
│   │   ├── analyze.ts        # AI simulation + Storage upload
│   │   ├── assessments.ts    # CRUD + Signed URLs
│   │   ├── prices.ts         # Harga komoditas (cached)
│   │   └── admin.ts          # Verifikasi + Batch ID search
│   └── _components/          # Reusable UI components
├── lib/
│   ├── batch-id.ts           # generateBatchId()
│   ├── image-compressor.ts   # compressImage() + generateBlurDataUrl()
│   ├── exif-validator.ts     # extractExifDate() + isPhotoTooOld()
│   ├── haptic.ts             # Vibration API wrapper
│   ├── offline-queue.ts      # IndexedDB operations
│   ├── export-pdf.ts         # jspdf client-side export
│   ├── export-csv.ts         # Native Blob API export
│   ├── validations.ts        # Zod schemas
│   ├── contrast-mode.ts      # High Contrast Mode
│   ├── i18n.ts               # Label Bahasa Indonesia
│   └── logger.ts             # Structured logging [AgriGrade][Action]
├── public/
│   └── sw.js                 # Service Worker
├── supabase/
│   ├── migrations/schema.sql # Full DB schema (disaster recovery)
│   └── functions/
│       └── cleanup-old-images/ # Edge Function cleanup >3 bulan
├── __tests__/
│   ├── unit/                 # Example-based tests
│   ├── property/             # fast-check property tests (P01–P13)
│   └── integration/          # Supabase mock tests
├── middleware.ts             # Proteksi /admin/* via cookie
├── agrigrade-config.json     # Single Source of Truth konfigurasi
└── .env.example              # Template env vars (safe to commit)
```

---

## 🔐 Security Notes

- **Private Storage Bucket** — gambar tidak bisa diakses via URL langsung; semua akses via Signed URLs TTL 1 jam
- **RLS Enabled** — Row Level Security aktif sejak awal di semua tabel; siap diperketat saat autentikasi penuh diimplementasikan
- **Zod Validation** — semua Server Actions memvalidasi input sebelum menyentuh database (defense in depth: kompresi 500KB di client + validasi 500KB di server)
- **httpOnly Cookie** — session admin disimpan di httpOnly cookie, tidak bisa diakses JavaScript
- **GPS Anti-Fraud** — koordinat selalu diambil real-time saat tombol ditekan, bukan dari cache

---

## 🗺️ Roadmap

- [ ] Autentikasi petani penuh (Supabase Auth) + RLS berbasis `farmer_id`
- [ ] Integrasi model AI nyata (replace simulasi)
- [ ] Peta sebaran kualitas tani (heatmap koordinat Grade A)
- [ ] Notifikasi push saat harga komoditas berubah
- [ ] Multi-komoditas (Lada, Kayu Manis, dll.)

---

## 📄 License

MIT — dibuat untuk Hackathon AgriGrade × Sima Arome.

---

<div align="center">
  <sub>Dibangun dengan ❤️ untuk petani Indonesia 🌾</sub>
</div>
