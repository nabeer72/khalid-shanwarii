# SATA POS Mobile App

This is the offline-first mobile Point of Sale (POS) application for SATA POS.

## Features
-   **Offline-First**: Works without an internet connection using a local SQLite database.
-   **Synchronization**: Syncs data with the Laravel backend when online.
-   **Scanning**: Built-in camera scanner for barcodes.
-   **Multi-Tenancy**: Supports login for different businesses using the same app.

## Documentation
- [Stock Management Process](STOCK_MANAGEMENT.md): Detailed overview of how inventory, batches, and price variants are handled.

## Project Structure
-   `lib/db`: Database helpers and schema definitions (`sqflite`).
-   `lib/models`: Dart data models matching the database schema.
-   `lib/screens`: UI screens (`Login`, `Home`, `Sales`).
-   `lib/services`:
    -   `api_service.dart`: HTTP client (Dio) with Authentication.
    -   `sync_service.dart`: Logic to Push/Pull data from backend.


## Configuration

### Permissions
The app requires **Camera** permission for scanning. This has been added to `android/app/src/main/AndroidManifest.xml`.

### 1. API URL
Open `lib/services/api_service.dart` and update the `baseUrl`:
```dart
// For Emulator
static const String baseUrl = 'http://10.0.2.2:8000/api';

// For Physical Device (same Wi-Fi)
static const String baseUrl = 'https://pos.sata.pk/api';
```

### 2. Run
```bash
flutter pub get
flutter run
```

### 3. Build APK
```bash
flutter build apk --release
```
