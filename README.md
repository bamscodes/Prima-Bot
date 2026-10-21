# PrimaBot

Chatbot asisten Rumah Sakit Prima Insan Mulia berbasis Flutter.

## Fitur Utama

- Chatbot RAG berbasis data RS lokal (`assets/data_rs.json`) dengan jawaban AI via OpenRouter (model gratis, fallback cepat tanpa pesan "layanan padat").
- TTS on-device memakai Piper (`flutter_piper_tts`): satu suara Indonesia resmi (`news_tts`) dan dua suara English (`amy` & `lessac`), langsung pakai tanpa download, pratinjau di pengaturan.
- Riwayat obrolan lokal SQLite, pencarian realtime, mode gelap/terang.

## Cara Build (PENTING)

Paket `dart_piper_tts` memakai Rust (`ort`/ONNX Runtime) yang **hanya menyediakan
binary prebuilt untuk Android arm64**. Karena itu build WAJIB dibatasi ke arm64:

```bash
# Debug (untuk testing di HP fisik, semua HP modern sudah arm64)
flutter build apk --debug --target-platform android-arm64

# Release
flutter build apk --release --target-platform android-arm64
```

Syarat lingkungan build:

1. **Rust toolchain** terpasang (`rustup`) dengan target Android:
   `rustup target add aarch64-linux-android`
2. **Android NDK 28.2.13676358** di `C:\MAD\android\Sdk\ndk\`.
3. Environment variable (sudah disetel permanen via `setx`):
   - `ANDROID_NDK_HOME=C:\MAD\android\Sdk\ndk\28.2.13676358`
   - `ANDROID_NDK_ROOT=C:\MAD\android\Sdk\ndk\28.2.13676358`

   Variabel ini dibutuhkan hook `android_libcpp_shared` untuk menemukan NDK yang
   benar (tanpa ini, hook menemukan NDK 27 lama di `%LOCALAPPDATA%\Android\Sdk`
   dan gagal dengan "No suitable NDK found").
4. Jika perintah `flutter` macet tanpa output, hapus lock usang:
   `C:\MAD\flutter\bin\cache\lockfile` dan `flutter.bat.lock`.

Catatan: build pertama kali mengompilasi crate Rust (ort, dsb.) sehingga bisa
memakan waktu 15-30 menit; build berikutnya memakai cache sehingga jauh lebih cepat.
