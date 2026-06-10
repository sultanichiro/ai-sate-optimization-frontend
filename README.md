# 📱 Flutter Frontend Project

Aplikasi frontend berbasis **Flutter (Dart)** untuk sistem proyek Tugas Akhir.

Repository ini berisi source code yang dapat langsung dijalankan di berbagai device (Android, iOS, Emulator, maupun Web).

---

# 🚀 Cara Menjalankan Project

## 1. Install Flutter & Dart

Flutter sudah include Dart, jadi cukup install Flutter saja.

### 🔽 Download Flutter

Download di sini:
https://docs.flutter.dev/get-started/install

---

### 📦 Extract Flutter

* Extract ke folder, misalnya:

```
C:\flutter
```

---

### ⚙️ Tambahkan ke PATH

Tambahkan:

```
C:\flutter\bin
```

ke Environment Variables → PATH

---

### ✅ Cek Instalasi

Buka terminal lalu jalankan:

```
flutter doctor
```

Pastikan tidak ada error penting.

---

## 2. Install Android Studio (Optional tapi disarankan)

Download:
https://developer.android.com/studio

Install:

* Android SDK
* Emulator (AVD)

---

## 3. Clone Project

```
git clone https://github.com/USERNAME/NAMA_REPO.git
cd NAMA_REPO
```

---

## 4. Install Dependencies

Jalankan:

```
flutter pub get
```

---

## 5. Jalankan Aplikasi

### 🔹 Cek device tersedia

```
flutter devices
```

### 🔹 Jalankan app

```
flutter run
```

---

# 📱 Menjalankan di Device

## 🔌 Android (HP langsung)

1. Aktifkan:

   * Developer Options
   * USB Debugging

2. Hubungkan HP ke laptop

3. Jalankan:

```
flutter run
```

---

## 💻 Emulator Android

1. Buka Android Studio
2. Jalankan Emulator
3. Jalankan:

```
flutter run
```

---

## 🌐 Web (opsional)

```
flutter run -d chrome
```

---

# 📦 Build APK (Untuk Dibagikan)

## 🔨 Build APK

```
flutter build apk
```

File hasil:

```
build/app/outputs/flutter-apk/app-release.apk
```

👉 Kirim file ini ke device lain → install langsung

---

## 📲 Install APK di Device

1. Kirim file `.apk`
2. Aktifkan:

   * Install from unknown sources
3. Install aplikasi

---

# 📁 Struktur Project

```
lib/
├── main.dart
├── screens/
├── widgets/
├── services/
```

---

# ⚠️ Catatan Penting

## 🔐 Jangan upload:

* file `.env`
* API key
* credential sensitif

---

## 🧹 File yang tidak ikut Git

Sudah diatur di `.gitignore`:

* build/
* .dart_tool/
* .idea/
* .vscode/

---

# 🧪 Troubleshooting

## ❌ Error saat `flutter run`

Coba:

```
flutter clean
flutter pub get
```

---

## ❌ Device tidak terdeteksi

Cek:

```
flutter devices
```

Jika kosong:

* pastikan USB Debugging aktif
* install driver HP

---

## ❌ Gradle error

```
flutter clean
```

---

# 📌 Versi yang Direkomendasikan

* Flutter: stable latest
* Dart: mengikuti Flutter

---

# 👨‍💻 Developer

Project ini dibuat untuk keperluan Tugas Akhir.

---

# 🚀 Next Improvement

* Integrasi backend API
* Optimasi UI/UX
* Deployment ke Play Store

---

# ⭐ Cara Berkontribusi

1. Fork repo
2. Buat branch baru
3. Commit perubahan
4. Pull request

---

# 📄 License

Free to use for educational purposes.
