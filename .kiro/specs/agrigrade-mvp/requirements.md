# Requirements Document

## Introduction

AgriGrade adalah platform kurasi hasil tani berbasis mobile-first yang membantu petani melakukan penilaian kualitas komoditas (seperti Vanili dan Cengkeh) secara mandiri menggunakan kamera smartphone. Hasil penilaian disimpan di database dan digunakan untuk menyuplai informasi ke perusahaan fragrance (Sima Arome). Aplikasi dibangun dengan Next.js (App Router), Tailwind CSS, Supabase, dan Shadcn UI.

## Glossary

- **AgriGrade**: Nama aplikasi platform kurasi hasil tani.
- **App**: Aplikasi web AgriGrade yang berjalan di browser mobile petani.
- **Dashboard**: Halaman utama yang menampilkan harga komoditas terkini dan riwayat scan petani.
- **Camera_Page**: Halaman yang memungkinkan petani mengambil atau mengunggah foto komoditas.
- **Result_Page**: Halaman yang menampilkan hasil analisis kualitas setelah scan.
- **AI_Analyzer**: Fungsi server-side yang memproses gambar dan mengembalikan hasil analisis kualitas.
- **Assessment**: Satu record hasil scan yang menyimpan URL gambar, grade, ID petani, dan timestamp.
- **Assessments_Table**: Tabel Supabase yang menyimpan semua data Assessment.
- **Grade**: Klasifikasi kualitas komoditas, bernilai 'A' atau 'B'.
- **Petani**: Pengguna utama aplikasi yang melakukan scan komoditas di lapangan.
- **Komoditas**: Hasil tani yang dinilai kualitasnya, contoh: Vanili, Cengkeh.
- **Confidence**: Nilai kepercayaan hasil analisis AI, berupa angka desimal antara 0 dan 1.
- **Disease**: Indikator boolean apakah komoditas terdeteksi memiliki penyakit.
- **Factory_Map**: Komponen peta yang menampilkan lokasi pabrik Sima Arome terdekat.
- **Batch_ID**: Kode unik alfanumerik yang di-generate setelah scan sukses, digunakan untuk menghubungkan karung fisik petani dengan record Assessment di sistem.
- **Supabase_Storage**: Layanan penyimpanan file objek dari Supabase yang digunakan untuk menyimpan file gambar komoditas.
- **Image_Compressor**: Fungsi sisi klien yang mengompresi gambar sebelum diunggah ke Supabase_Storage.
- **Service_Worker**: Script background browser yang memungkinkan fitur PWA seperti caching dan Background Sync.
- **Background_Sync**: Mekanisme Service_Worker yang mengantri operasi gagal dan mengeksekusinya ulang saat koneksi internet pulih.
- **Offline_Queue**: Penyimpanan lokal (IndexedDB) yang menyimpan data Assessment sementara saat koneksi tidak tersedia.
- **Prices_Table**: Tabel Supabase yang menyimpan harga komoditas terkini, digunakan sebagai sumber data harga dinamis di Dashboard.
- **EXIF_Validator**: Fungsi sisi klien yang mengekstrak dan memvalidasi metadata EXIF dari file gambar, digunakan untuk mendeteksi apakah foto yang diunggah merupakan foto baru atau foto lama.
- **Admin_Page**: Halaman verifikasi di rute `/admin/verify` yang hanya dapat diakses oleh admin pabrik Sima Arome, digunakan untuk memverifikasi dan mengkoreksi grade hasil analisis AI.

---

## Requirements

### Requirement 1: Dashboard Petani

**User Story:** Sebagai petani, saya ingin melihat dashboard yang menampilkan harga komoditas terkini dan riwayat scan saya, sehingga saya dapat memantau nilai hasil tani dan histori penilaian dengan mudah.

#### Acceptance Criteria

1. THE App SHALL menampilkan halaman Dashboard sebagai halaman utama (`/`) yang dapat diakses tanpa autentikasi pada fase MVP.
2. THE Dashboard SHALL menampilkan daftar harga komoditas (minimal Vanili dan Cengkeh) beserta satuan harga per kilogram.
3. THE Dashboard SHALL mengambil data harga komoditas secara real-time dari Prices_Table di Supabase, bukan dari nilai yang di-hardcode di kode UI.
4. THE Dashboard SHALL menampilkan daftar riwayat scan (Assessments) milik petani yang sedang login, diurutkan berdasarkan timestamp terbaru.
5. WHEN riwayat scan kosong, THE Dashboard SHALL menampilkan pesan "Belum ada riwayat scan" kepada petani.
6. THE Dashboard SHALL menyediakan tombol navigasi menuju Camera_Page untuk memulai scan baru.
7. THE App SHALL menggunakan skema warna Hijau Organik (`#16a34a` sebagai warna primer) dan Putih Bersih (`#ffffff` sebagai latar belakang) pada seluruh halaman.
8. THE App SHALL dirender dengan layout mobile-first dengan lebar maksimum 480px yang terpusat di layar desktop.

---

### Requirement 2: Halaman Kamera (Scan Komoditas)

**User Story:** Sebagai petani, saya ingin mengambil foto komoditas langsung dari kamera smartphone saya, sehingga saya dapat melakukan penilaian kualitas secara mandiri di lapangan.

#### Acceptance Criteria

1. THE Camera_Page SHALL dapat diakses melalui rute `/scan`.
2. THE Camera_Page SHALL menyediakan elemen `<input type="file" accept="image/*" capture="environment">` untuk mengakses kamera belakang smartphone.
3. WHEN petani memilih gambar, THE Camera_Page SHALL menampilkan pratinjau gambar yang dipilih sebelum dikirim untuk analisis.
4. THE Camera_Page SHALL menyediakan tombol "Analisis Sekarang" yang aktif hanya setelah gambar dipilih.
5. WHEN tombol "Analisis Sekarang" ditekan, THE Camera_Page SHALL menampilkan animasi loading selama proses analisis berlangsung.
6. WHEN tombol "Analisis Sekarang" ditekan, THE Camera_Page SHALL mengirim gambar ke AI_Analyzer melalui Server Action.
7. WHEN analisis selesai, THE App SHALL mengarahkan petani ke Result_Page dengan membawa data hasil analisis.
8. IF terjadi error saat mengunggah atau menganalisis gambar, THEN THE Camera_Page SHALL menampilkan pesan error yang deskriptif kepada petani.
9. WHEN tombol "Analisis Sekarang" ditekan, THE Camera_Page SHALL mengambil koordinat GPS secara real-time menggunakan `navigator.geolocation.getCurrentPosition()` pada saat tombol ditekan, bukan menggunakan koordinat yang tersimpan dari sesi atau interaksi sebelumnya.
10. THE Camera_Page SHALL hanya menggunakan koordinat GPS yang diperoleh dari pemanggilan `getCurrentPosition()` yang dipicu langsung oleh aksi tombol "Analisis Sekarang" untuk memastikan keotentikan data lokasi dan mencegah penggunaan koordinat lama atau palsu.
11. IF `navigator.geolocation` tidak tersedia atau petani menolak izin lokasi, THEN THE Camera_Page SHALL tetap melanjutkan proses analisis dengan nilai `latitude` dan `longitude` bernilai `null`, dan SHALL menampilkan pesan peringatan bahwa data lokasi tidak tersedia.
12. WHEN petani memilih gambar, THE EXIF_Validator SHALL mencoba mengekstrak metadata EXIF dari file gambar tersebut, khususnya nilai `DateTimeOriginal`.
13. WHEN tombol "Analisis Sekarang" ditekan dan nilai `DateTimeOriginal` dari EXIF berhasil diekstrak, THE EXIF_Validator SHALL membandingkan `DateTimeOriginal` dengan waktu saat tombol ditekan.
14. IF selisih waktu antara `DateTimeOriginal` dari EXIF dan waktu saat tombol "Analisis Sekarang" ditekan melebihi 24 jam, THEN THE Camera_Page SHALL menampilkan pesan peringatan kepada petani bahwa foto terdeteksi bukan foto baru, namun SHALL tetap mengizinkan petani melanjutkan proses analisis tanpa memblokir.
15. IF metadata EXIF tidak tersedia pada file gambar yang dipilih, THEN THE Camera_Page SHALL tetap melanjutkan proses analisis tanpa menampilkan peringatan apapun terkait EXIF.
16. WHEN analisis AI tidak merespons dalam 10 detik, THE Camera_Page SHALL secara otomatis menyimpan data ke Offline_Queue dan menampilkan notifikasi "Koneksi lambat. Data tersimpan lokal dan akan diunggah otomatis."
17. WHEN `getCurrentPosition()` gagal atau ditolak, THE App SHALL menandai Assessment dengan flag `is_mock_location: true` untuk membedakan dari Assessment dengan data GPS valid.

---

### Requirement 3: Fungsi Analisis AI (Simulasi)

**User Story:** Sebagai sistem, saya ingin memiliki fungsi analisis gambar di sisi server yang mensimulasikan penilaian kualitas AI, sehingga alur kerja scan dapat didemonstrasikan pada fase MVP tanpa model AI yang sesungguhnya.

#### Acceptance Criteria

1. THE AI_Analyzer SHALL menerima data gambar (sebagai FormData atau base64 string) dari Camera_Page.
2. THE AI_Analyzer SHALL berjalan sepenuhnya di sisi server (menggunakan Server Action atau Route Handler).
3. WHEN dipanggil, THE AI_Analyzer SHALL memberikan delay 2000 milidetik untuk mensimulasikan waktu pemrosesan.
4. WHEN delay selesai, THE AI_Analyzer SHALL mengembalikan objek JSON dengan struktur `{ grade: 'A' | 'B', confidence: number, disease: boolean }`.
5. THE AI_Analyzer SHALL menghasilkan nilai `grade` secara acak ('A' atau 'B') pada setiap pemanggilan.
6. THE AI_Analyzer SHALL menghasilkan nilai `confidence` berupa angka desimal acak antara 0.80 dan 0.99.
7. THE AI_Analyzer SHALL menghasilkan nilai `disease` berupa boolean acak.
8. WHEN AI_Analyzer mengembalikan hasil, THE App SHALL menyimpan satu record Assessment baru ke Assessments_Table di Supabase.

---

### Requirement 4: Halaman Hasil Scan

**User Story:** Sebagai petani, saya ingin melihat hasil penilaian kualitas komoditas saya beserta lokasi pabrik terdekat, sehingga saya dapat mengetahui grade produk dan ke mana harus menjualnya.

#### Acceptance Criteria

1. THE Result_Page SHALL dapat diakses melalui rute `/result` setelah proses analisis selesai.
2. THE Result_Page SHALL menampilkan nilai Grade hasil analisis ('A' atau 'B') dengan visual yang jelas dan menonjol.
3. THE Result_Page SHALL menampilkan nilai Confidence sebagai persentase (contoh: "98%").
4. THE Result_Page SHALL menampilkan status Disease dengan label "Terdeteksi Penyakit" jika `disease: true`, atau "Sehat" jika `disease: false`.
5. THE Result_Page SHALL menampilkan Factory_Map yang menunjukkan lokasi pabrik Sima Arome terdekat menggunakan embed peta statis atau iframe Google Maps.
6. THE Result_Page SHALL menyediakan tombol "Scan Lagi" yang mengarahkan petani kembali ke Camera_Page.
7. THE Result_Page SHALL menyediakan tombol "Kembali ke Dashboard" yang mengarahkan petani ke Dashboard.
8. WHEN Grade bernilai 'A', THE Result_Page SHALL menampilkan latar belakang atau badge berwarna hijau pada indikator grade.
9. WHEN Grade bernilai 'B', THE Result_Page SHALL menampilkan latar belakang atau badge berwarna kuning pada indikator grade.
10. WHEN data EXIF `DateTimeOriginal` tersedia, THE Result_Page SHALL menampilkan "Waktu Pengambilan Foto" beserta tanggal dan waktu yang diekstrak dari metadata EXIF.
11. WHEN analisis selesai sukses, THE App SHALL memicu getaran pendek (200ms) menggunakan Vibration API jika perangkat mendukung.
12. WHEN terjadi error saat analisis, THE App SHALL memicu pola getaran dua kali (100ms-50ms-100ms) menggunakan Vibration API jika perangkat mendukung.

---

### Requirement 5: Skema Database Assessments

**User Story:** Sebagai sistem, saya ingin menyimpan setiap hasil scan ke database, sehingga riwayat penilaian dapat diambil kembali dan ditampilkan di Dashboard.

#### Acceptance Criteria

1. THE Assessments_Table SHALL memiliki kolom `id` bertipe UUID sebagai primary key yang di-generate secara otomatis.
2. THE Assessments_Table SHALL memiliki kolom `image_url` bertipe TEXT untuk menyimpan URL gambar komoditas yang di-scan.
3. THE Assessments_Table SHALL memiliki kolom `grade` bertipe TEXT (nilai: 'A' atau 'B') untuk menyimpan hasil penilaian kualitas.
4. THE Assessments_Table SHALL memiliki kolom `confidence` bertipe FLOAT untuk menyimpan nilai kepercayaan analisis.
5. THE Assessments_Table SHALL memiliki kolom `disease` bertipe BOOLEAN untuk menyimpan status penyakit komoditas.
6. THE Assessments_Table SHALL memiliki kolom `farmer_id` bertipe TEXT untuk menyimpan identifikasi petani (dapat berupa nilai statis pada fase MVP).
7. THE Assessments_Table SHALL memiliki kolom `created_at` bertipe TIMESTAMPTZ yang di-set secara otomatis ke waktu saat record dibuat.
8. WHEN sebuah Assessment baru disimpan, THE App SHALL dapat mengambil kembali (query) semua Assessment berdasarkan `farmer_id` untuk ditampilkan di Dashboard.
9. THE App SHALL menggunakan Supabase client di sisi server untuk semua operasi baca dan tulis ke Assessments_Table.
10. THE Assessments_Table SHALL memiliki kolom `latitude` bertipe FLOAT (nullable) untuk menyimpan koordinat GPS lintang lokasi scan.
11. THE Assessments_Table SHALL memiliki kolom `longitude` bertipe FLOAT (nullable) untuk menyimpan koordinat GPS bujur lokasi scan.
12. THE Assessments_Table SHALL memiliki kolom `batch_id` bertipe TEXT (nullable, unique) untuk menyimpan kode Batch_ID yang di-generate setelah scan sukses.
13. THE Assessments_Table SHALL memiliki kolom `is_verified` bertipe BOOLEAN dengan nilai default `false` untuk menyimpan status verifikasi manual oleh admin pabrik.
14. THE Assessments_Table SHALL memiliki Row Level Security (RLS) yang di-enable di Supabase sejak awal, sebelum fitur autentikasi penuh diimplementasikan.
15. WHILE fase MVP berjalan tanpa autentikasi penuh, THE Assessments_Table SHALL memiliki RLS policy yang mengizinkan semua operasi (`SELECT`, `INSERT`, `UPDATE`, `DELETE`) untuk memudahkan proses development, dengan catatan eksplisit bahwa policy ini HARUS diperketat menjadi policy berbasis `farmer_id` saat autentikasi diimplementasikan.
16. WHERE autentikasi telah diimplementasikan, THE Assessments_Table SHALL membatasi akses data hanya kepada petani yang memiliki `farmer_id` yang sesuai dengan identitas autentikasi mereka, menggunakan RLS policy berbasis kolom `farmer_id`.
17. THE Assessments_Table SHALL memiliki kolom `is_mock_location` bertipe BOOLEAN dengan nilai default `false` untuk menandai Assessment yang disubmit tanpa data GPS valid.
18. THE Assessments_Table SHALL memiliki kolom `blur_data_url` bertipe TEXT (nullable) untuk menyimpan base64 thumbnail 8x8px yang digunakan sebagai blur-up placeholder di Dashboard.

---

### Requirement 6: Penyimpanan Gambar dengan Supabase Storage

**User Story:** Sebagai sistem, saya ingin menyimpan file gambar komoditas di Supabase Storage dan mengompresi gambar di sisi klien sebelum diunggah, sehingga biaya penyimpanan terkendali dan kuota data petani tidak terkuras oleh file berukuran besar.

#### Acceptance Criteria

1. THE App SHALL menggunakan Supabase_Storage sebagai tempat penyimpanan fisik semua file gambar komoditas yang di-scan.
2. THE Image_Compressor SHALL mengompresi gambar di sisi klien (browser) sebelum gambar diunggah ke Supabase_Storage.
3. THE Image_Compressor SHALL mengompresi gambar hingga ukuran maksimum 500 kilobyte sebelum diunggah, tanpa memperhatikan ukuran file asli.
4. THE Image_Compressor SHALL mempertahankan rasio aspek (aspect ratio) gambar asli selama proses kompresi.
5. WHEN kompresi selesai, THE Camera_Page SHALL menampilkan ukuran file hasil kompresi kepada petani sebelum proses analisis dimulai.
6. WHEN gambar berhasil diunggah ke Supabase_Storage, THE App SHALL menyimpan URL publik gambar tersebut ke kolom `image_url` di Assessments_Table.
7. THE App SHALL menyimpan file gambar di Supabase_Storage dalam bucket bernama `commodity-images` dengan path `{farmer_id}/{assessment_id}.jpg`.
8. IF proses unggah gambar ke Supabase_Storage gagal, THEN THE Camera_Page SHALL menampilkan pesan error yang deskriptif dan tidak melanjutkan proses analisis AI.
9. THE App SHALL menggunakan Supabase Storage private bucket (bukan public) untuk menyimpan gambar komoditas.
10. THE App SHALL menggunakan Supabase Signed URLs dengan TTL 3600 detik untuk setiap akses gambar di Dashboard dan Admin Page, mencegah akses tidak sah via URL langsung.
11. WHEN kolom `image_url` bernilai `'[DELETED]'` (gambar telah dihapus oleh cleanup job), THE App SHALL menampilkan placeholder "Gambar tidak tersedia" alih-alih broken image.

---

### Requirement 7: Batch ID dan Traceability

**User Story:** Sebagai petani, saya ingin mendapatkan kode Batch ID unik setelah setiap scan sukses, sehingga saya dapat menuliskan kode tersebut di karung komoditas dan admin pabrik Sima Arome dapat mencocokkan kiriman fisik dengan data di sistem.

#### Acceptance Criteria

1. WHEN analisis AI selesai dan Assessment berhasil disimpan, THE App SHALL men-generate satu Batch_ID unik untuk Assessment tersebut.
2. THE App SHALL men-generate Batch_ID dengan format `AG-{YYYYMMDD}-{6 karakter alfanumerik acak huruf kapital}` (contoh: `AG-20250715-X4K9MZ`).
3. THE Result_Page SHALL menampilkan Batch_ID dengan visual yang menonjol dan mudah dibaca.
4. THE Result_Page SHALL menyediakan tombol "Salin Kode" yang menyalin Batch_ID ke clipboard petani.
5. WHEN tombol "Salin Kode" ditekan, THE Result_Page SHALL menampilkan konfirmasi visual (contoh: teks berubah menjadi "Tersalin!") selama 2000 milidetik.
6. THE App SHALL menyimpan Batch_ID ke kolom `batch_id` di Assessments_Table bersamaan dengan penyimpanan Assessment.
7. THE Dashboard SHALL menampilkan Batch_ID pada setiap item di daftar riwayat scan.
8. THE Assessments_Table SHALL memastikan nilai `batch_id` bersifat unik di seluruh tabel (unique constraint).

---

### Requirement 8: PWA dan Kemampuan Offline

**User Story:** Sebagai petani, saya ingin aplikasi tetap dapat digunakan di area dengan sinyal lemah atau tanpa koneksi internet, sehingga saya tidak kehilangan data hasil scan meskipun koneksi terputus saat proses berlangsung.

#### Acceptance Criteria

1. THE App SHALL memenuhi kriteria Progressive Web App (PWA) sehingga dapat diinstal di layar utama smartphone petani.
2. THE App SHALL menyertakan file `manifest.json` dengan properti `name`, `short_name`, `icons`, `start_url`, `display: standalone`, dan `theme_color`.
3. THE App SHALL mendaftarkan Service_Worker yang melakukan caching aset statis (HTML, CSS, JavaScript) agar halaman dapat dimuat tanpa koneksi internet.
4. WHEN petani menyelesaikan analisis tetapi koneksi internet tidak tersedia, THE App SHALL menyimpan data Assessment (grade, confidence, disease, batch_id, image_url, latitude, longitude) ke Offline_Queue di IndexedDB perangkat petani.
5. WHEN koneksi internet tidak tersedia saat penyimpanan, THE Result_Page SHALL menampilkan notifikasi "Data tersimpan lokal, akan diunggah otomatis saat sinyal kembali" kepada petani.
6. WHEN koneksi internet pulih, THE Service_Worker SHALL secara otomatis mengunggah semua data Assessment yang tersimpan di Offline_Queue ke Supabase menggunakan mekanisme Background_Sync.
7. WHEN Background_Sync berhasil mengunggah semua data dari Offline_Queue, THE App SHALL menghapus data tersebut dari Offline_Queue.
8. IF Background_Sync gagal setelah 3 kali percobaan ulang, THEN THE App SHALL menampilkan notifikasi kepada petani bahwa data perlu diunggah secara manual.
9. THE Dashboard SHALL menampilkan indikator jumlah Assessment yang masih tersimpan di Offline_Queue dan belum tersinkronisasi ke server.

---

### Requirement 9: Skema Database Prices (Sumber Data Harga Dinamis)

**User Story:** Sebagai sistem, saya ingin menyimpan harga komoditas di database, sehingga harga yang ditampilkan di Dashboard selalu terkini dan dapat diperbarui tanpa perlu mengubah kode aplikasi.

#### Acceptance Criteria

1. THE Prices_Table SHALL memiliki kolom `id` bertipe UUID sebagai primary key yang di-generate secara otomatis.
2. THE Prices_Table SHALL memiliki kolom `commodity_name` bertipe TEXT untuk menyimpan nama komoditas (contoh: 'Vanili', 'Cengkeh').
3. THE Prices_Table SHALL memiliki kolom `price_per_kg` bertipe NUMERIC untuk menyimpan harga komoditas per kilogram.
4. THE Prices_Table SHALL memiliki kolom `unit` bertipe TEXT dengan nilai default 'IDR' untuk menyimpan satuan mata uang harga.
5. THE Prices_Table SHALL memiliki kolom `updated_at` bertipe TIMESTAMPTZ yang di-set secara otomatis ke waktu saat record terakhir diperbarui.
6. THE App SHALL menggunakan Supabase client di sisi server untuk semua operasi baca ke Prices_Table.
7. WHEN data harga di Prices_Table diperbarui, THE Dashboard SHALL menampilkan harga terbaru pada pemuatan halaman berikutnya tanpa perubahan kode aplikasi.

---

### Requirement 10: Halaman Admin Verifikasi

**User Story:** Sebagai admin pabrik Sima Arome, saya ingin memiliki halaman khusus untuk memverifikasi dan mengkoreksi grade hasil analisis AI, sehingga kualitas data yang masuk ke sistem dapat dijamin akurasinya sebelum digunakan untuk keputusan bisnis.

#### Acceptance Criteria

1. THE Admin_Page SHALL dapat diakses melalui rute `/admin/verify`.
2. THE Admin_Page SHALL dilindungi dengan mekanisme autentikasi password sederhana menggunakan nilai dari environment variable `ADMIN_PASSWORD`, bukan sistem autentikasi penuh.
3. IF password yang dimasukkan tidak sesuai dengan nilai `ADMIN_PASSWORD`, THEN THE Admin_Page SHALL menolak akses dan menampilkan pesan error kepada pengguna.
4. THE Admin_Page SHALL menampilkan daftar semua Assessment dengan nilai `is_verified = false`, diurutkan berdasarkan kolom `created_at` terbaru.
5. THE Admin_Page SHALL menampilkan informasi berikut untuk setiap Assessment dalam daftar: gambar komoditas, grade hasil AI, nilai confidence, batch_id, dan data farmer_id.
6. THE Admin_Page SHALL menyediakan tombol "Verifikasi Grade A" untuk setiap Assessment yang belum diverifikasi.
7. THE Admin_Page SHALL menyediakan tombol "Turunkan ke Grade B" untuk setiap Assessment yang belum diverifikasi.
8. WHEN admin menekan tombol "Verifikasi Grade A", THE Admin_Page SHALL mengupdate kolom `is_verified` menjadi `true` pada Assessment yang bersangkutan di Assessments_Table tanpa mengubah nilai kolom `grade`.
9. WHEN admin menekan tombol "Turunkan ke Grade B", THE Admin_Page SHALL mengupdate kolom `is_verified` menjadi `true` dan kolom `grade` menjadi 'B' pada Assessment yang bersangkutan di Assessments_Table.
10. WHEN sebuah Assessment berhasil diverifikasi, THE Admin_Page SHALL menghapus Assessment tersebut dari daftar yang ditampilkan tanpa perlu memuat ulang seluruh halaman.

---

### Requirement 11: Lokalisasi dan Aksesibilitas Lapangan

**User Story:** Sebagai petani yang bekerja di lapangan terbuka, saya ingin aplikasi menggunakan Bahasa Indonesia yang mudah dipahami dan memiliki tampilan yang tetap terbaca di bawah sinar matahari terik, sehingga saya dapat menggunakan aplikasi dengan nyaman tanpa kesulitan membaca layar.

#### Acceptance Criteria

1. THE App SHALL menggunakan Bahasa Indonesia sebagai bahasa utama di seluruh antarmuka, termasuk label tombol, pesan error, notifikasi, dan teks instruksi.
2. THE App SHALL mengganti semua istilah teknis dengan padanan Bahasa Indonesia yang mudah dipahami petani: "Confidence" → "Tingkat Keakuratan", "Grade" → "Kelas Mutu", "Disease" → "Status Kesehatan", "Batch ID" → "Kode Karung".
3. THE App SHALL menyediakan fitur High Contrast Mode yang dapat diaktifkan/dinonaktifkan oleh petani melalui tombol toggle di halaman Dashboard.
4. WHEN High Contrast Mode aktif, THE App SHALL menampilkan teks dengan warna hitam pekat (#000000) di atas latar belakang putih (#ffffff) atau kuning terang (#fbbf24) untuk elemen interaktif, dengan ukuran font minimal 16px untuk semua teks konten.
5. THE App SHALL menyimpan preferensi High Contrast Mode petani di localStorage sehingga pengaturan tetap tersimpan saat aplikasi dibuka kembali.
6. THE App SHALL menggunakan ukuran tombol minimal 48x48px (touch target) untuk semua elemen interaktif agar mudah ditekan dengan jari di lapangan.
7. THE App SHALL memastikan semua gambar dan ikon memiliki atribut `alt` dalam Bahasa Indonesia untuk aksesibilitas screen reader.

---

### Requirement 12: Ekspor Data dan Laporan Mandiri Petani

**User Story:** Sebagai petani, saya ingin dapat mengekspor ringkasan hasil scan saya dalam format yang bisa dibagikan atau dicetak, sehingga saya dapat menggunakan laporan tersebut sebagai bukti kualitas saat bernegosiasi harga dengan pengepul atau sebagai arsip pribadi.

#### Acceptance Criteria

1. THE Result_Page SHALL menyediakan tombol "Unduh Laporan" yang menghasilkan ringkasan scan dalam format PDF.
2. THE PDF report SHALL memuat informasi: Kode Karung (Batch ID), Kelas Mutu (Grade), Tingkat Keakuratan (Confidence %), Status Kesehatan (Disease), nama komoditas, tanggal scan, dan nama aplikasi AgriGrade sebagai header.
3. THE Dashboard SHALL menyediakan tombol "Ekspor Riwayat" yang mengunduh semua riwayat scan petani dalam format CSV.
4. THE CSV export SHALL memuat kolom: batch_id, grade, confidence, disease, created_at, latitude, longitude, image_url.
5. THE App SHALL menghasilkan file PDF dan CSV sepenuhnya di sisi klien (browser) tanpa mengirim data ke server, menggunakan library JavaScript.
6. WHEN file berhasil dibuat, THE App SHALL memicu unduhan otomatis ke perangkat petani dengan nama file yang deskriptif (contoh: `agrigrade-laporan-AG-20250715-X4K9MZ.pdf` atau `agrigrade-riwayat-20250715.csv`).
