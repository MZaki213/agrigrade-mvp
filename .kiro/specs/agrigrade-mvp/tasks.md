# Implementation Plan: AgriGrade MVP

## Overview

Rencana implementasi ini menguraikan langkah-langkah pengembangan AgriGrade MVP secara bertahap dalam 5 fase. Setiap fase membangun di atas fase sebelumnya, dimulai dari fondasi infrastruktur hingga fitur lengkap yang siap deploy. Bahasa implementasi: **TypeScript** (Next.js 16 App Router + React 19).

## Tasks

---

## Phase 1: Project Setup & Database

- [x] 1. Setup environment dan konfigurasi proyek
  - [x] 1.1 Inisialisasi dependensi: install Tailwind CSS v4, Shadcn UI, Supabase client (`@supabase/supabase-js`, `@supabase/ssr`), Zod, exifr, idb, jspdf, `@vercel/analytics`, `@vercel/speed-insights`
    - Jalankan `npx shadcn@latest init` untuk setup Shadcn UI dengan tema default
    - Pastikan `next.config.ts` dikonfigurasi untuk security headers dan Service Worker static file serving
    - _Requirements: 1.7, 1.8_
  - [x] 1.2 Buat file `types/database.ts` dengan TypeScript types lengkap
    - Definisikan `Grade = 'A' | 'B'`
    - Definisikan interface `Assessment` (14 kolom sesuai skema: id, image_url, grade, confidence, disease, farmer_id, created_at, latitude, longitude, batch_id, is_verified, image_deleted_at, blur_data_url, is_mock_location)
    - Definisikan `AssessmentInsert = Omit<Assessment, 'id' | 'created_at' | 'is_verified'>`
    - Definisikan interface `Price` (id, commodity_name, price_per_kg, unit, updated_at)
    - Definisikan interface `OfflineAssessmentData` (grade, confidence, disease, batch_id, image_url, latitude, longitude, farmer_id, queued_at)
    - _Requirements: 5.1–5.18, 9.1–9.5_
  - [x] 1.3 Buat file `lib/supabase/client.ts` (Supabase browser client) dan `lib/supabase/server.ts` (Supabase server client untuk Server Actions dan RSC)
    - `client.ts`: gunakan `createBrowserClient` dari `@supabase/ssr`
    - `server.ts`: gunakan `createServerClient` dari `@supabase/ssr` dengan cookie handling Next.js
    - _Requirements: 5.9, 9.6_
  - [x] 1.4 Buat file `.env.local` template dengan semua environment variables yang dibutuhkan
    - `NEXT_PUBLIC_SUPABASE_URL`
    - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
    - `ADMIN_PASSWORD` (tanpa prefix NEXT_PUBLIC_ — server-only)
    - _Requirements: 10.2_
  - [x] 1.5 Buat file `.env.example` untuk portabilitas proyek
    - Salin semua key dari `.env.local` tanpa nilai asli (kosongkan valuenya)
    - Tambahkan komentar singkat di atas setiap key menjelaskan cara mendapatkan nilainya
    - Contoh: `# Dapatkan dari Supabase Dashboard → Project Settings → API`
    - Commit file ini ke Git (tidak mengandung secret); `.env.local` tetap di `.gitignore`
    - _Infrastruktur: memastikan siapa pun yang clone repo tahu persis env vars yang dibutuhkan_

- [x] 2. Setup skema database Supabase
  - [x] 2.1 Buat SQL migration untuk `assessments_table` dengan 14 kolom lengkap
    - Kolom: id (UUID PK), image_url (TEXT NOT NULL), grade (TEXT CHECK IN 'A','B'), confidence (FLOAT CHECK 0–1), disease (BOOLEAN DEFAULT false), farmer_id (TEXT NOT NULL), created_at (TIMESTAMPTZ DEFAULT now()), latitude (FLOAT nullable), longitude (FLOAT nullable), batch_id (TEXT UNIQUE nullable), is_verified (BOOLEAN DEFAULT false), image_deleted_at (TIMESTAMPTZ nullable), blur_data_url (TEXT nullable), is_mock_location (BOOLEAN DEFAULT false)
    - _Requirements: 5.1–5.18_
  - [x] 2.2 Tambahkan RLS dan indexes pada `assessments_table`
    - `ALTER TABLE assessments_table ENABLE ROW LEVEL SECURITY`
    - MVP policy: `CREATE POLICY "mvp_allow_all_assessments" ON assessments_table FOR ALL USING (true) WITH CHECK (true)`
    - Index: `idx_assessments_farmer_id_created_at ON (farmer_id, created_at DESC)`
    - Index: `idx_assessments_is_verified ON (is_verified, created_at DESC)`
    - Sertakan komentar eksplisit bahwa policy MVP HARUS diperketat saat auth diimplementasikan
    - _Requirements: 5.14, 5.15, 5.16_
  - [x] 2.3 Buat SQL migration untuk `prices_table` dengan trigger dan seed data
    - Kolom: id (UUID PK), commodity_name (TEXT NOT NULL), price_per_kg (NUMERIC(12,2) NOT NULL), unit (TEXT DEFAULT 'IDR'), updated_at (TIMESTAMPTZ DEFAULT now())
    - Trigger `prices_updated_at`: auto-update `updated_at` saat row di-UPDATE via fungsi `update_updated_at_column()`
    - RLS: `ALTER TABLE prices_table ENABLE ROW LEVEL SECURITY` + policy `mvp_allow_read_prices` FOR SELECT USING (true)
    - Seed data: Vanili 3.500.000 IDR/kg, Cengkeh 85.000 IDR/kg
    - _Requirements: 9.1–9.7_
  - [x] 2.4 Buat Supabase Storage private bucket `commodity-images`
    - Bucket visibility: PRIVATE (bukan public)
    - Path pattern: `{farmer_id}/{assessment_id}.jpg`
    - Max file size: 500KB, MIME type: image/jpeg
    - Dokumentasikan bahwa akses gambar hanya via Signed URLs TTL 3600 detik
    - _Requirements: 6.1, 6.7, 6.9, 6.10_
  - [x] 2.5 Simpan seluruh SQL schema ke `supabase/migrations/schema.sql`
    - Gabungkan semua DDL dari task 2.1–2.3 ke satu file: CREATE TABLE assessments_table, CREATE TABLE prices_table, trigger `update_updated_at_column`, semua RLS policies, semua indexes, dan seed data
    - Tambahkan komentar header di file: tanggal dibuat, versi schema, dan instruksi singkat cara apply (`paste ke Supabase SQL Editor`)
    - Commit file ini ke Git sebagai disaster recovery — jika project Supabase dihapus atau akun berganti, seluruh struktur DB bisa dibangun ulang dalam hitungan detik
    - _Infrastruktur: portabilitas dan keamanan schema database_

- [x] 3. Setup CI/CD pipeline
  - [x] 3.1 Buat file `.github/workflows/ci.yml` untuk GitHub Actions
    - Trigger: push ke semua branch dan pull request ke main
    - Steps: checkout, setup Node.js, install dependencies, run lint (`next lint`), run type check (`tsc --noEmit`), run tests (`vitest --run`)
    - _Requirements: (infrastruktur)_

- [ ] 4. Checkpoint Phase 1 — Pastikan semua tes lulus, tanyakan kepada user jika ada pertanyaan.

---

## Phase 2: Core Logic & AI Simulation

- [ ] 5. Implementasi utility libraries (lib/)
  - [ ] 5.1 Buat `lib/validations.ts` — Zod schemas untuk semua Server Actions
    - `AnalyzeImageSchema`: file `z.instanceof(File).refine(type starts with 'image/').refine(size <= 512000)`, coords.latitude `z.number().min(-90).max(90).nullable()`, coords.longitude `z.number().min(-180).max(180).nullable()`
    - `AssessmentInsertSchema`: validasi semua field sebelum INSERT ke Supabase (grade IN ['A','B'], confidence 0–1, dll.)
    - `BatchIdSearchSchema`: batchId `z.string().regex(/^AG-\d{8}-[A-Z0-9]{6}$/)`
    - Semua schema mengembalikan discriminated union `{ success: true, data: T } | { success: false, error: string, code: 'VALIDATION_ERROR' }`
    - _Requirements: 3.1, 5.1–5.6, 7.2_
  - [ ] 5.2 Buat `lib/batch-id.ts` — fungsi `generateBatchId()`
    - Format: `AG-{YYYYMMDD}-{6 karakter alfanumerik acak huruf kapital}`
    - Contoh output: `AG-20250715-X4K9MZ`
    - Gunakan `Date` untuk bagian tanggal dan `Math.random()` + `toString(36).toUpperCase()` untuk 6 karakter acak
    - _Requirements: 7.1, 7.2_
  - [ ]* 5.3 Tulis property test untuk `generateBatchId()` — Property P03 dan P04
    - **Property P03: Batch ID selalu cocok regex `^AG-\d{8}-[A-Z0-9]{6}$`**
    - **Validates: Requirements 7.2**
    - **Property P04: Batch ID unik — tidak ada duplikat dalam 1000 pemanggilan**
    - **Validates: Requirements 5.12, 7.8**
    - File: `__tests__/unit/batch-id.test.ts`
  - [ ] 5.4 Buat `lib/image-compressor.ts` — fungsi `compressImage()` dan `generateBlurDataUrl()`
    - `compressImage(file, maxSizeKB=500)`: Canvas API iterative quality reduction (mulai quality=0.9, turunkan 0.1 per iterasi) hingga ukuran ≤ 500KB; pertahankan aspect ratio; kembalikan `{ blob, sizeKB, width, height }`
    - `generateBlurDataUrl(blob)`: canvas 8x8px → drawImage → `canvas.toDataURL('image/jpeg', 0.5)` → base64 string
    - Jika gambar sudah ≤ 500KB, kembalikan langsung tanpa kompresi
    - _Requirements: 6.2, 6.3, 6.4, 5.18_
  - [ ]* 5.5 Tulis property test untuk `compressImage()` — Property P05 dan P06
    - **Property P05: `compressImage()` mempertahankan aspect ratio (toleransi ±0.01)**
    - **Validates: Requirements 6.4**
    - **Property P06: `compressImage()` menghasilkan file ≤ 500KB untuk input apapun**
    - **Validates: Requirements 6.3**
    - File: `__tests__/unit/image-compressor.test.ts`
  - [ ] 5.6 Buat `lib/exif-validator.ts` — fungsi `extractExifDate()` dan `isPhotoTooOld()`
    - `extractExifDate(file)`: gunakan library `exifr` untuk ekstrak `DateTimeOriginal`; kembalikan `Date | null`
    - `isPhotoTooOld(exifDate, referenceTime, thresholdHours=24)`: kembalikan `true` jika selisih > 24 jam
    - _Requirements: 2.12, 2.13, 2.14, 2.15_
  - [ ]* 5.7 Tulis property test untuk `isPhotoTooOld()` — Property P07
    - **Property P07: `isPhotoTooOld()` return true jika dan hanya jika selisih > 24 jam**
    - **Validates: Requirements 2.13, 2.14**
    - File: `__tests__/unit/exif-validator.test.ts`
  - [ ] 5.8 Buat `lib/haptic.ts` — wrapper Vibration API
    - `vibrateSuccess()`: `navigator.vibrate(200)` — getaran pendek 200ms
    - `vibrateError()`: `navigator.vibrate([100, 50, 100])` — pola dua getaran
    - `isVibrationSupported()`: `typeof navigator !== 'undefined' && 'vibrate' in navigator`
    - Graceful degradation: semua fungsi no-op jika Vibration API tidak tersedia
    - _Requirements: 4.11, 4.12_
  - [ ] 5.9 Buat `lib/logger.ts` — structured logging wrapper
    - `logError(actionName, error)`: format `[AgriGrade][{actionName}] error: ${error.message}` ke `console.error`
    - `logInfo(actionName, message)`: format `[AgriGrade][{actionName}] ${message}` ke `console.log`
    - Output visible di Vercel Function Logs
    - Gunakan di semua Server Actions untuk semua blok `catch` — memudahkan filter log di Vercel Dashboard saat debugging scan gagal di production
    - _Infrastruktur logging — digunakan oleh semua Server Actions di Phase 2_

- [ ] 6. Implementasi Server Actions
  - [ ] 6.1 Buat `app/actions/analyze.ts` — Server Action `analyzeImage()`
    - Validasi input dengan `AnalyzeImageSchema` (Zod) sebelum diproses
    - Upload gambar ke Supabase Storage bucket `commodity-images` path `{farmer_id}/{assessment_id}.jpg`
    - Jika upload gagal: kembalikan `{ success: false, error: 'Gagal mengunggah gambar. Coba lagi.', code: 'STORAGE_ERROR' }`
    - Delay 2000ms (`await new Promise(r => setTimeout(r, 2000))`) untuk simulasi AI
    - Generate hasil acak: grade ('A'|'B'), confidence (0.80–0.99), disease (boolean)
    - Panggil `generateBatchId()` untuk generate Batch ID
    - Panggil `saveAssessment()` untuk INSERT ke Assessments_Table
    - Return `{ success: true, data: { grade, confidence, disease, batchId, imageUrl, assessmentId } }`
    - Gunakan `logError()` untuk semua error
    - _Requirements: 3.1–3.8, 6.6, 6.7, 6.8, 7.1_
  - [ ]* 6.2 Tulis property test untuk `analyzeImage()` — Property P02
    - **Property P02: AI Analyzer: grade ∈ {'A','B'}, confidence ∈ [0.80,0.99], disease ∈ boolean**
    - **Validates: Requirements 3.4, 3.5, 3.6, 3.7**
    - File: `__tests__/property/ai-analyzer.test.ts`
  - [ ] 6.3 Buat `app/actions/assessments.ts` — Server Actions untuk CRUD assessments
    - `saveAssessment(data: AssessmentInsert)`: validasi dengan `AssessmentInsertSchema`, INSERT ke Supabase, kembalikan `{ success: boolean, id?: string, error?: string, code?: string }`
    - `getAssessments(farmerId)`: SELECT dari Assessments_Table WHERE farmer_id = farmerId ORDER BY created_at DESC; gunakan `unstable_cache` dengan tag 'assessments' dan revalidate 60 detik
    - `getSignedImageUrl(path)`: `supabase.storage.from('commodity-images').createSignedUrl(path, 3600)`; jika path adalah '[DELETED]' kembalikan null tanpa memanggil Supabase
    - _Requirements: 3.8, 5.8, 5.9, 6.10, 6.11_
  - [ ]* 6.4 Tulis property test untuk `getAssessments()` — Property P01
    - **Property P01: Assessment list selalu terurut descending by created_at**
    - **Validates: Requirements 1.4**
    - File: `__tests__/property/assessments-sort.test.ts`
  - [ ] 6.5 Buat `app/actions/prices.ts` — Server Action `getPrices()`
    - SELECT semua baris dari Prices_Table
    - Gunakan `unstable_cache` dengan tag 'prices' dan revalidate 3600 detik
    - Kembalikan `Price[]`
    - _Requirements: 9.6, 9.7_
  - [ ] 6.6 Buat `app/actions/admin.ts` — Server Actions untuk admin
    - `verifyAdminPassword(password)`: bandingkan dengan `process.env.ADMIN_PASSWORD`; jika cocok set httpOnly cookie `agrigrade_admin_session` (httpOnly: true, secure: true, sameSite: 'strict'); kembalikan `{ success: boolean, error?: string, code?: string }`
    - `verifyAssessmentGrade(assessmentId)`: UPDATE assessments_table SET is_verified=true WHERE id=assessmentId; kembalikan `{ success: boolean }`
    - `downgradeAssessmentToB(assessmentId)`: UPDATE assessments_table SET is_verified=true, grade='B' WHERE id=assessmentId; kembalikan `{ success: boolean }`
    - `searchAssessmentByBatchId(batchId)`: validasi dengan `BatchIdSearchSchema`; SELECT * FROM assessments_table WHERE batch_id = batchId LIMIT 1; kembalikan `Assessment | null`
    - _Requirements: 10.2, 10.3, 10.8, 10.9_
  - [ ]* 6.7 Tulis property test untuk `verifyAdminPassword()` — Property P11
    - **Property P11: hanya ADMIN_PASSWORD yang return true**
    - **Validates: Requirements 10.2, 10.3**
    - File: `__tests__/property/admin-auth.test.ts`
  - [ ]* 6.8 Tulis property test untuk `searchAssessmentByBatchId()` — Property P13
    - **Property P13: exact match atau null — tidak boleh return record berbeda**
    - **Validates: Requirement 7 (Batch ID & Traceability)**
    - File: `__tests__/property/batch-id-search.test.ts`

- [ ] 7. Implementasi middleware autentikasi admin
  - [ ] 7.1 Buat `middleware.ts` di root project
    - Proteksi semua rute `/admin/*` kecuali `/admin/login`
    - Cek keberadaan cookie `agrigrade_admin_session`
    - Jika cookie tidak ada atau tidak valid: redirect ke `/admin/login`
    - _Requirements: 10.1, 10.2_

- [ ] 8. Checkpoint Phase 2 — Pastikan semua tes lulus, tanyakan kepada user jika ada pertanyaan.

---

## Phase 3: PWA & Offline Feature

- [ ] 9. Implementasi Offline Queue (IndexedDB)
  - [ ] 9.1 Buat `lib/offline-queue.ts` — operasi IndexedDB via library `idb`
    - Konfigurasi: DB name `agrigrade-offline`, version 1, store name `offline_queue`, key auto-increment integer
    - `enqueueAssessment(data: OfflineAssessmentData)`: tambahkan item ke store `offline_queue`
    - `dequeueAll()`: ambil semua item dari store, kembalikan `OfflineAssessmentData[]`
    - `clearQueue()`: hapus semua item dari store setelah Background Sync berhasil
    - `getQueueCount()`: kembalikan jumlah item pending di store (digunakan oleh `OfflineIndicator`)
    - _Requirements: 8.4, 8.7, 8.9_
  - [ ]* 9.2 Tulis property test untuk offline queue round-trip — Property P10
    - **Property P10: data yang di-enqueue identik dengan yang di-dequeue (field-by-field)**
    - **Validates: Requirements 8.4**
    - File: `__tests__/property/offline-queue.test.ts`

- [ ] 10. Implementasi Service Worker dan PWA
  - [ ] 10.1 Buat `public/sw.js` — Service Worker dengan static caching dan Background Sync
    - Install event: cache aset statis (HTML, CSS, JS, icons) menggunakan Cache API
    - Fetch event: serve dari cache jika tersedia (cache-first strategy untuk aset statis)
    - Sync event: tangani tag `'agrigrade-assessment-sync'`
      - Panggil `dequeueAll()` untuk ambil semua data pending dari IndexedDB
      - Untuk setiap item: POST ke Server Action `saveAssessment()` via fetch
      - Retry logic: maksimum 3 kali dengan exponential backoff (1s, 2s, 4s)
      - Jika semua berhasil: panggil `clearQueue()`
      - Jika gagal setelah 3x: kirim notifikasi ke user bahwa data perlu diunggah manual
    - _Requirements: 8.3, 8.6, 8.7, 8.8_
  - [ ] 10.2 Buat `app/manifest.ts` — PWA manifest menggunakan Next.js `MetadataRoute.Manifest`
    - Properti: name "AgriGrade", short_name "AgriGrade", start_url "/", display "standalone", theme_color "#16a34a", background_color "#ffffff"
    - Icons: icon-192x192.png dan icon-512x512.png di folder `public/icons/`
    - _Requirements: 8.1, 8.2_
  - [ ] 10.3 Tambahkan registrasi Service Worker di `app/layout.tsx` (root layout)
    - Gunakan `useEffect` di Client Component wrapper atau inline script untuk register `/sw.js`
    - Cek `'serviceWorker' in navigator` sebelum register (graceful degradation)
    - _Requirements: 8.3_
  - [ ] 10.4 Setup local tunneling untuk pengujian PWA di perangkat fisik
    - Gunakan **VS Code Port Forwarding** (built-in, tanpa install tambahan): buka panel Ports di VS Code → Forward port 3000 → set visibility ke Public → salin URL HTTPS yang dihasilkan
    - Alternatif: gunakan `ngrok http 3000` jika VS Code Port Forwarding tidak tersedia
    - Buka URL HTTPS tersebut di HP fisik untuk test: Service Worker registration, Haptic Feedback (getaran), Camera API (`capture="environment"`), dan PWA install prompt
    - HTTPS wajib untuk Service Worker dan Camera API — localhost di laptop tidak cukup untuk test di HP
    - _Infrastruktur: validasi PWA dan fitur hardware di perangkat asli sebelum deploy ke Vercel_

- [ ] 11. Implementasi circuit breaker di scan page
  - [ ] 11.1 Tambahkan circuit breaker `Promise.race()` 10 detik di `app/scan/page.tsx`
    - Buat `analyzeWithTimeout(formData, coords)`: `Promise.race([analyzeImage(formData, coords), timeout(10000)])`
    - Jika timeout: panggil `enqueueAssessment()` untuk simpan data ke IndexedDB, tampilkan notifikasi "Koneksi lambat. Data tersimpan lokal dan akan diunggah otomatis.", navigate ke `/result` dengan data lokal dari sessionStorage
    - _Requirements: 2.16_

- [ ] 12. Checkpoint Phase 3 — Pastikan semua tes lulus, tanyakan kepada user jika ada pertanyaan.

---

## Phase 4: UI & Accessibility

- [ ] 13. Setup global styles dan aksesibilitas
  - [ ] 13.1 Update `app/globals.css` — CSS custom properties dan high-contrast overrides
    - Definisikan CSS variables: `--color-primary: #16a34a`, `--color-bg: #ffffff`, `--color-grade-a: green`, `--color-grade-b: yellow`
    - High-contrast overrides: `.high-contrast` class pada `<html>` → teks `#000000`, bg `#ffffff`, elemen interaktif `#fbbf24`, font-size minimal 16px untuk semua teks konten
    - Tailwind v4 base styles dan utility classes
    - _Requirements: 1.7, 11.4_
  - [ ] 13.2 Buat `lib/contrast-mode.ts` — utility read/write preferensi High Contrast ke localStorage
    - Key localStorage: `'agrigrade_high_contrast'`
    - `getContrastMode()`: baca dari localStorage, kembalikan boolean
    - `setContrastMode(enabled)`: tulis ke localStorage, toggle class `'high-contrast'` pada `<html>` element
    - _Requirements: 11.3, 11.5_
  - [ ] 13.3 Buat `lib/i18n.ts` — konstanta label Bahasa Indonesia
    - Ekspor objek dengan semua label UI: confidence → "Tingkat Keakuratan", grade → "Kelas Mutu", disease → "Status Kesehatan", batch_id → "Kode Karung", dll.
    - Sertakan semua label dari `ui_labels_id` di agrigrade-config.json
    - _Requirements: 11.1, 11.2_

- [ ] 14. Implementasi komponen UI reusable
  - [ ] 14.1 Buat `app/_components/HighContrastToggle.tsx` — tombol toggle High Contrast Mode
    - Baca state awal dari `getContrastMode()` (localStorage)
    - Toggle class `'high-contrast'` pada `<html>` dan simpan ke localStorage via `setContrastMode()`
    - Touch target minimal 48x48px
    - Label dalam Bahasa Indonesia, atribut `aria-pressed` untuk aksesibilitas
    - _Requirements: 11.3, 11.5, 11.6_
  - [ ] 14.2 Buat `app/_components/GradeBadge.tsx` — badge grade A/B dengan warna
    - Grade 'A': background hijau (`bg-green-600` atau CSS variable), teks putih
    - Grade 'B': background kuning (`bg-yellow-400` atau CSS variable), teks hitam
    - Props: `grade: Grade`
    - Atribut `aria-label` dalam Bahasa Indonesia ("Kelas Mutu A" / "Kelas Mutu B")
    - _Requirements: 4.2, 4.8, 4.9_
  - [ ]* 14.3 Tulis unit test untuk `GradeBadge` — Property P09
    - **Property P09: grade A → CSS green, grade B → CSS yellow (konsisten)**
    - **Validates: Requirements 4.8, 4.9**
    - File: `__tests__/unit/grade-badge.test.ts`
  - [ ] 14.4 Buat `app/_components/PriceCard.tsx` — kartu harga komoditas
    - Props: `price: Price`
    - Tampilkan nama komoditas, harga per kg dalam format Rupiah (Intl.NumberFormat 'id-ID'), satuan
    - _Requirements: 1.2, 1.3_
  - [ ] 14.5 Buat `app/_components/AssessmentHistoryItem.tsx` — item riwayat scan di Dashboard
    - Gunakan `next/image` (bukan `<img>`) untuk thumbnail dengan `placeholder="blur"` dan `blurDataURL` dari kolom `blur_data_url`
    - Fetch signed URL via Server Action `getSignedImageUrl()` sebelum render (karena bucket private)
    - Jika `image_url === '[DELETED]'`: tampilkan placeholder "Gambar tidak tersedia" (JANGAN panggil `getSignedImageUrl()`)
    - Tampilkan: GradeBadge, Batch ID ("Kode Karung"), tanggal scan, confidence sebagai persentase
    - Atribut `alt` dalam Bahasa Indonesia untuk semua gambar
    - _Requirements: 1.4, 6.10, 6.11, 7.7_
  - [ ] 14.6 Buat `app/_components/BatchIdDisplay.tsx` — tampilan Batch ID dengan tombol salin
    - Tampilkan Batch ID dengan visual menonjol (font besar, monospace)
    - Tombol "Salin Kode": salin ke clipboard via `navigator.clipboard.writeText()`
    - Konfirmasi visual: teks berubah menjadi "Tersalin!" selama 2000ms, lalu kembali ke "Salin Kode"
    - Touch target minimal 48x48px
    - _Requirements: 7.3, 7.4, 7.5_
  - [ ] 14.7 Buat `app/_components/FactoryMap.tsx` — embed peta lokasi pabrik Sima Arome
    - Gunakan Google Maps iframe embed (static embed, bukan Maps JavaScript API)
    - Atribut `title` dalam Bahasa Indonesia untuk aksesibilitas iframe
    - _Requirements: 4.5_
  - [ ] 14.8 Buat `app/_components/OfflineIndicator.tsx` — indikator item pending di Offline Queue
    - Client Component: panggil `getQueueCount()` dari `lib/offline-queue.ts`
    - Tampilkan jumlah item pending jika > 0: "X data belum tersinkronisasi"
    - Sembunyikan jika queue kosong
    - _Requirements: 8.9_
  - [ ] 14.9 Buat `app/_components/AdminAssessmentRow.tsx` — baris assessment di halaman admin
    - Fetch signed URL via `getSignedImageUrl()` untuk tampilkan gambar
    - Tampilkan badge/ikon untuk assessment dengan `is_mock_location: true`
    - Tampilkan: gambar, grade AI, confidence %, batch_id, farmer_id
    - Tombol "Verifikasi Grade A" dan "Turunkan ke Grade B" (touch target 48x48px)
    - _Requirements: 10.4, 10.5, 10.6, 10.7_

- [ ] 15. Implementasi halaman-halaman utama
  - [ ] 15.1 Update `app/layout.tsx` — root layout dengan semua integrasi
    - Tambahkan `<Analytics />` dari `@vercel/analytics/react` dan `<SpeedInsights />` dari `@vercel/speed-insights/next`
    - Tambahkan script inline untuk FOUC prevention: baca `localStorage.getItem('agrigrade_high_contrast')` dan apply class `'high-contrast'` ke `<html>` sebelum first paint
    - Registrasi Service Worker via Client Component wrapper (cek `'serviceWorker' in navigator`)
    - Meta tags PWA: `theme-color`, `apple-mobile-web-app-capable`, viewport mobile-first
    - _Requirements: 1.8, 8.1, 11.5_
  - [ ] 15.2 Update `app/page.tsx` — Dashboard (Server Component)
    - Fetch data: `await getPrices()` dan `await getAssessments('farmer_mvp_001')` di server
    - Render: header dengan `HighContrastToggle`, daftar `PriceCard`, `OfflineIndicator`, daftar `AssessmentHistoryItem`
    - Jika riwayat kosong: tampilkan pesan "Belum ada riwayat scan"
    - Tombol navigasi ke `/scan` (touch target 48x48px)
    - Tombol "Ekspor Riwayat" (Client Component wrapper untuk trigger `exportAssessmentsCSV()`)
    - Layout: `max-w-[480px] mx-auto`, warna primer `#16a34a`, bg `#ffffff`
    - _Requirements: 1.1–1.8, 12.3_
  - [ ] 15.3 Buat `app/scan/page.tsx` — Camera Page (Client Component) dengan semua fitur REQ-02
    - State: `selectedFile`, `previewUrl`, `compressedSize`, `isLoading`, `error`, `gpsWarning`, `exifWarning`
    - `handleFileChange(e)`: EXIF validation (`extractExifDate()`) + image compression (`compressImage()`) + generate `blurDataUrl` + tampilkan preview dan ukuran file hasil kompresi
    - `handleAnalyze()`:
      1. Panggil `getCurrentPosition()` real-time (bukan dari cache)
      2. Jika GPS gagal/ditolak: set `is_mock_location=true`, latitude/longitude=null, tampilkan warning
      3. Cek EXIF: jika `isPhotoTooOld()` → tampilkan warning non-blocking
      4. Panggil `analyzeWithTimeout()` (circuit breaker 10 detik)
      5. Jika sukses: `vibrateSuccess()`, simpan data ke sessionStorage, navigate ke `/result`
      6. Jika error: `vibrateError()`, tampilkan pesan error deskriptif
    - Input: `<input type="file" accept="image/*" capture="environment">`
    - Tombol "Analisis Sekarang" disabled sampai gambar dipilih
    - Animasi loading saat analisis berlangsung
    - _Requirements: 2.1–2.17_
  - [ ]* 15.4 Tulis property test untuk GPS freshness — Property P12
    - **Property P12: GPS coords yang dikirim ke Server Action selalu dari `getCurrentPosition()` terbaru**
    - **Validates: Requirements 2.9, 2.10**
    - File: `__tests__/property/gps-freshness.test.ts`
  - [ ] 15.5 Buat `app/result/page.tsx` — Result Page (Client Component) dengan semua fitur REQ-04
    - Baca data dari sessionStorage (dikirim dari scan page setelah analisis)
    - Tampilkan: `GradeBadge`, confidence sebagai `Math.round(confidence * 100) + '%'`, disease status ("Terdeteksi Penyakit" / "Sehat"), `BatchIdDisplay`, `FactoryMap`
    - Jika EXIF `DateTimeOriginal` tersedia (dari sessionStorage): tampilkan "Waktu Pengambilan Foto: {tanggal dan waktu}"
    - `vibrateSuccess()` saat halaman dimuat dengan data sukses
    - Tombol "Unduh Laporan" → panggil `exportScanReportPDF(assessment)` (client-side)
    - Tombol "Scan Lagi" → `/scan`, tombol "Kembali ke Dashboard" → `/`
    - _Requirements: 4.1–4.12, 12.1, 12.2_
  - [ ]* 15.6 Tulis unit test untuk result formatter — Property P08
    - **Property P08: Confidence ditampilkan sebagai `Math.round(confidence * 100) + '%'`**
    - **Validates: Requirements 4.3**
    - File: `__tests__/unit/result-formatter.test.ts`
  - [ ] 15.7 Buat `app/admin/login/page.tsx` — Admin Login Page (Client Component)
    - Form input password dengan label "Password Admin"
    - Submit → panggil Server Action `verifyAdminPassword(password)`
    - Jika sukses: redirect ke `/admin/verify`
    - Jika gagal: tampilkan pesan error "Password tidak valid."
    - Touch target minimal 48x48px untuk semua elemen interaktif
    - _Requirements: 10.2, 10.3_
  - [ ] 15.8 Buat `app/admin/verify/page.tsx` — Admin Verify Page (Client Component)
    - State: `assessments[]`, `searchQuery`, `searchResult`
    - Fetch daftar assessments dengan `is_verified=false` ordered by `created_at DESC` via Server Action
    - Search bar: input text untuk Batch ID search → panggil `searchAssessmentByBatchId(batchId)`
    - Tampilkan single result card jika ditemukan, atau "Kode tidak ditemukan" jika tidak ada
    - Render daftar `AdminAssessmentRow` di bawah search bar
    - Tombol "Verifikasi Grade A": panggil `verifyAssessmentGrade(id)`, hapus item dari daftar tanpa reload
    - Tombol "Turunkan ke Grade B": panggil `downgradeAssessmentToB(id)`, hapus item dari daftar tanpa reload
    - _Requirements: 10.1, 10.4–10.10_

- [ ] 16. Checkpoint Phase 4 — Pastikan semua tes lulus, tanyakan kepada user jika ada pertanyaan.

---

## Phase 5: Final Touches

- [ ] 17. Implementasi fitur ekspor data
  - [ ] 17.1 Buat `lib/export-pdf.ts` — client-side PDF generation via jspdf
    - `exportScanReportPDF(assessment: Assessment)`: generate PDF dengan layout:
      - Header: "AgriGrade" sebagai judul aplikasi
      - Kode Karung (Batch ID)
      - Kelas Mutu (Grade)
      - Tingkat Keakuratan (Confidence %)
      - Status Kesehatan (Disease)
      - Tanggal scan
    - Trigger download otomatis: `agrigrade-laporan-{batch_id}.pdf`
    - Generate sepenuhnya di browser — data TIDAK dikirim ke server
    - _Requirements: 12.1, 12.2, 12.5, 12.6_
  - [ ] 17.2 Buat `lib/export-csv.ts` — client-side CSV generation via native Blob API
    - `exportAssessmentsCSV(assessments: Assessment[])`: generate CSV dengan kolom: batch_id, grade, confidence, disease, created_at, latitude, longitude, image_url
    - Gunakan `Blob` API native + `URL.createObjectURL()` + `<a>` element dengan atribut `download`
    - Trigger download otomatis: `agrigrade-riwayat-{YYYYMMDD}.csv`
    - Generate sepenuhnya di browser — data TIDAK dikirim ke server
    - _Requirements: 12.3, 12.4, 12.5, 12.6_
  - [ ] 17.3 Integrasi tombol "Unduh Laporan" di `app/result/page.tsx`
    - Tombol sudah ada dari Phase 4; pastikan memanggil `exportScanReportPDF(assessment)` dengan data assessment yang benar dari sessionStorage
    - Verifikasi nama file: `agrigrade-laporan-{batch_id}.pdf`
    - _Requirements: 12.1, 12.6_
  - [ ] 17.4 Integrasi tombol "Ekspor Riwayat" di `app/page.tsx` (Dashboard)
    - Tombol sudah ada dari Phase 4; pastikan memanggil `exportAssessmentsCSV(assessments)` dengan data assessments yang di-pass dari Server Component
    - Verifikasi nama file: `agrigrade-riwayat-{YYYYMMDD}.csv`
    - _Requirements: 12.3, 12.6_

- [ ] 18. Implementasi Supabase Edge Function cleanup
  - [ ] 18.1 Buat `supabase/functions/cleanup-old-images/index.ts` — Edge Function untuk cleanup gambar lama
    - Trigger: pg_cron setiap hari 02:00 UTC (dokumentasikan cara setup pg_cron di Supabase)
    - Query: SELECT id, image_url FROM assessments_table WHERE is_verified = true AND created_at < NOW() - INTERVAL '3 months' AND image_url != '[DELETED]'
    - Untuk setiap record: hapus file fisik di Storage via `supabase.storage.from('commodity-images').remove([path])`
    - UPDATE assessments_table SET image_url='[DELETED]', image_deleted_at=NOW() WHERE id=record.id
    - PENTING: Record di assessments_table TIDAK PERNAH dihapus — tetap ada untuk audit trail
    - _Requirements: 6.11_

- [ ] 19. Integration tests dan accessibility audit
  - [ ]* 19.1 Tulis integration tests di `__tests__/integration/`
    - `supabase-assessments.test.ts`: test INSERT dan SELECT assessments dengan Supabase mock
    - `supabase-prices.test.ts`: test SELECT prices dengan caching behavior
    - `service-worker-sync.test.ts`: test Background Sync flow (enqueue → sync → clearQueue)
    - _Requirements: 3.8, 5.8, 8.6, 8.7_
  - [ ] 19.2 Final accessibility audit
    - Verifikasi semua touch targets minimal 48x48px di semua halaman
    - Verifikasi semua gambar dan ikon memiliki atribut `alt` dalam Bahasa Indonesia
    - Verifikasi High Contrast Mode berfungsi di semua halaman (class `high-contrast` pada `<html>`)
    - Verifikasi FOUC prevention: class `high-contrast` ter-apply sebelum first paint
    - Verifikasi semua label tombol dalam Bahasa Indonesia
    - _Requirements: 11.1–11.7_

- [ ] 20. Vercel deployment setup
  - [ ] 20.1 Konfigurasi environment variables di Vercel dashboard
    - `NEXT_PUBLIC_SUPABASE_URL`
    - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
    - `ADMIN_PASSWORD`
    - Pastikan `ADMIN_PASSWORD` tidak memiliki prefix `NEXT_PUBLIC_` (server-only)
    - _Requirements: 10.2_
  - [ ] 20.2 Verifikasi deployment dan PWA installability
    - Pastikan `manifest.ts` ter-serve dengan benar di `/manifest.webmanifest`
    - Pastikan Service Worker ter-register dan cache aset statis
    - Pastikan semua Supabase connections berfungsi di production environment
    - _Requirements: 8.1, 8.2, 8.3_

- [ ] 21. Final checkpoint — Pastikan semua tes lulus, tanyakan kepada user jika ada pertanyaan.

---

## Notes

- Tasks bertanda `*` bersifat opsional dan dapat dilewati untuk MVP yang lebih cepat
- Setiap task mereferensikan requirements spesifik untuk traceability
- Checkpoint di setiap akhir fase memastikan validasi inkremental
- Property tests (P01–P13) memvalidasi correctness properties universal dari design document
- Unit tests memvalidasi contoh spesifik dan edge cases
- Bahasa implementasi: **TypeScript** (Next.js 16 App Router + React 19)
- MVP farmer_id statis: `farmer_mvp_001` (akan diganti dengan auth.uid() saat autentikasi diimplementasikan)
- Semua Server Actions menggunakan discriminated union: `{ success: true, data: T } | { success: false, error: string, code?: string }`
