Berikut adalah *Product Requirements Document* (PRD) yang telah disesuaikan secara komprehensif mencakup arsitektur *zero-cost*, integrasi AI ganda (IndoBERT + OpenRouter), penggunaan SQLite murni, manajemen sesi tanpa *login*, dan metode pembaruan data via JSON.

---

# PRODUCT REQUIREMENTS DOCUMENT (PRD)
**Nama Proyek:** Asisten Virtual Layanan Kesehatan (Chatbot)
**Institusi:** RS Prima Insan Mulia
**Platform:** Flutter (Frontend), Dart (Backend)
**Fase Dokumen:** Finalisasi Arsitektur & Kebutuhan Fitur

## 1. Ringkasan Eksekutif
Aplikasi ini adalah chatbot cerdas yang dirancang untuk memberikan informasi jadwal dokter dan layanan RS Prima Insan Mulia secara *real-time* kepada publik. Fokus utama pengembangan ini adalah menciptakan pengalaman pengguna yang instan tanpa hambatan (tanpa proses registrasi/login), sekaligus menekan biaya operasional server hingga titik nol (*zero-cost infrastructure*) menggunakan pemrosesan data lokal (SQLite) dan layanan AI pihak ketiga (*Serverless*).

## 2. Arsitektur Sistem & Tech Stack
Sistem menggunakan pendekatan arsitektur terpisah antara antarmuka pengguna, logika bisnis, dan model kecerdasan buatan.

* **Frontend:** Flutter (didistribusikan via Web/APK).
* **Backend:** Dart (berjalan di atas *container* gratis seperti Fly.io atau Render).
* **Database:** SQLite (penyimpanan lokal di *backend*, file `rs_prima_insan.db`).
* **Klasifikasi Niat (Intent):** Model IndoBERT, diakses secara *serverless* via Hugging Face Inference API (Gratis).
* **Generasi Teks (NLG):** Model LLM *Open-Source* (contoh: Llama-3 8B/Gemma) diakses via OpenRouter API ($0 *Tier*).

## 3. Kebutuhan Fungsional (Functional Requirements)

### 3.1. Sesi Chat Anonim (Tanpa Login)
* Aplikasi tidak memiliki halaman autentikasi. Pasien langsung diarahkan ke antarmuka obrolan saat aplikasi dibuka.
* Frontend Flutter bertugas men-generate UUID (*Universally Unique Identifier*) acak setiap kali aplikasi diluncurkan.
* UUID ini dikirim ke backend pada setiap request untuk menjaga konteks percakapan sementara selama pasien belum menutup aplikasi.

### 3.2. Pemrosesan Bahasa (AI Pipeline)
* **Routing Otomatis:** Setiap teks input dari pasien diteruskan oleh backend Dart ke Hugging Face API (IndoBERT) untuk mendeteksi *intent* (niat).
* **Query Lokal:** Berdasarkan *intent* yang didapat, backend melakukan pencarian jadwal/layanan ke dalam SQLite dengan waktu komputasi instan.
* **Respon Natural:** Data hasil *query* SQLite dan teks input digabungkan ke dalam *prompt* sistem, lalu dikirim ke OpenRouter untuk menghasilkan gaya bahasa yang empatik dan ramah sebelum ditampilkan ke pasien.

### 3.3. Manajemen Data Otomatis (JSON Seeder)
* Sistem tidak memerlukan panel admin visual yang kompleks.
* Pembaruan data layanan dan jadwal dokter dilakukan melalui injeksi file berformat JSON (`data_rs.json`).
* Backend memiliki fungsi utilitas internal yang, saat dieksekusi, akan mem-parsing JSON tersebut dan melakukan *insert* secara otomatis ke dalam tabel SQLite.

## 4. Skema Database Inti (SQLite)
Database dirancang seringkas mungkin, berfokus murni pada operasional rumah sakit tanpa ada tabel pengguna (*users*) maupun *password hashing*.

* **Tabel `layanan`**:
    * `id` (INTEGER, Primary Key)
    * `nama_layanan` (TEXT)
    * `deskripsi` (TEXT)
    * `lokasi_gedung` (TEXT)
* **Tabel `jadwal_dokter`**:
    * `id` (INTEGER, Primary Key)
    * `nama_dokter` (TEXT)
    * `spesialisasi` (TEXT)
    * `hari` (TEXT)
    * `jam_mulai` (TEXT)
    * `jam_selesai` (TEXT)
    * `id_layanan` (INTEGER, Foreign Key ke tabel `layanan`)

## 5. Alur Pengguna & Sistem (App Flow)
1. **Inisialisasi:** Pasien membuka aplikasi Flutter; UUID sesi dibuat; sapaan awal bot muncul.
2. **Input Pasien:** Pasien mengirim keluhan atau pertanyaan (Misal: *"Besok ada dokter gigi?"*).
3. **Analisis Niat:** Backend mengirim string ke IndoBERT via Hugging Face. Mengembalikan JSON: `{"intent": "Cari_Jadwal", "entitas": "gigi", "waktu": "besok"}`.
4. **Pencarian Data:** Backend menjalankan SQL: `SELECT * FROM jadwal_dokter WHERE spesialisasi LIKE '%gigi%' AND hari = 'Rabu'`.
5. **Penyusunan Respon:** Backend mengirim instruksi ke OpenRouter: *"Berdasarkan data SQLite [drg. Anita, 09:00-14:00], jawab pertanyaan pasien secara natural."*
6. **Tampilan Final:** Teks balasan dari OpenRouter dikirim ke Flutter dan ditampilkan di layar obrolan pasien.

## 6. Kebutuhan Non-Fungsional (Keamanan & Pemeliharaan)
* **Privasi Pasien:** Karena bersifat anonim, sistem dilarang meminta atau menyimpan data sensitif seperti Nomor Rekam Medis. Prompt OpenRouter diinstruksikan dengan tegas untuk menolak pertanyaan terkait rekam medis.
* **Persistent Storage:** Jika menggunakan layanan *deployment container*, file `.db` harus berada pada *Persistent Volume* agar data jadwal dari JSON tidak terhapus saat *server restart*.
* **Backup Data:** File `data_rs.json` berfungsi sebagai *Single Source of Truth* dan mekanisme *backup* fisik jika terjadi korupsi file SQLite.

---
Hak Cipta © 2026 - Bambang Sugiarto, M.Kom. | Pengembangan Sistem Informasi RS Prima Insan Mulia