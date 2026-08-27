# SATA POS Mobile App

This is the offline-first mobile Point of Sale (POS) application for SATA POS built with Flutter.

## Overview
The application is designed to function seamlessly even without an internet connection by utilizing a local SQLite database (`sqflite`). Once the connection is restored, it syncs data bidirectionally with the Laravel backend.

## Key Features
- **Offline-First Architecture**: Continuous operation without internet connectivity.
- **Robust Synchronization**: Background and manual sync to push/pull data with the central server.
- **Barcode Scanning**: Built-in camera scanner for rapid product lookup and checkout.
- **Multi-Tenancy Support**: Capable of handling logins for different businesses and branches using the same app.
- **Print & Share**: Built-in support for generating PDF receipts and sharing or printing them directly from the device.

## Application Modules

The application is comprehensive and includes the following fully implemented modules:

### 1. Point of Sale (POS) & Sales
- **POS Terminal**: Fast checkout interface (`pos_screen.dart`).
- **Standard Sales**: Detailed sales processing interface (`sales_screen.dart`).
- **Sales History**: Viewing past transactions (`sales_history_screen.dart`).
- **Order Holds**: Ability to pause and resume transactions (`held_orders_screen.dart`).
- **Barcode Scanner**: Camera-based product scanning (`scanner_screen.dart`).
- **Receipts**: Invoice generation and viewing (`receipt_screen.dart`).

### 2. Inventory & Product Management
- **Products**: Add, edit, and list products (`add_product_screen.dart`, `product_list_screen.dart`).
- **Stock Tracking**: Comprehensive stock reports and inventory tracking (`stock_report_screen.dart`).
- **Units**: Management of measurement units (`units_screen.dart`).
- **Brands**: Brand categorization (handled via models and product additions).

### 3. Purchases & Suppliers
- **Purchases**: Record and track inventory purchases (`purchases_screen.dart`, `add_purchase_screen.dart`).
- **Suppliers**: Manage supplier directories (`suppliers_screen.dart`, `add_supplier_screen.dart`).
- **Supplier Paybacks**: Track and record returns and financial settlements with suppliers (`supplier_payback_screen.dart`).

### 4. Customer & Loyalty Management
- **Customer Directory**: Add and manage customer details (`customer_list_screen.dart`).
- **Credit Sales**: Track credit accounts and customer balances (`customer_credit_sales_screen.dart`).
- **Loyalty Programs**: Points and rewards management for customers (`loyalty_screen.dart`).

### 5. Payments, Banking & Finance
- **Payment Processing**: Handle multiple payment types and split payments (`payment_screen.dart`, `payment_processing_screen.dart`).
- **Payment Methods**: Configure accepted payment types (`payment_types_screen.dart`).
- **Banking**: Manage bank accounts and transactions (`bank_management_screen.dart`, `manage_banks_screen.dart`).
- **Expenses**: Record daily business expenses (`expenses_screen.dart`).
- **Cash Management**: Denomination and currency notes tracking (`currency_notes_screen.dart`).
- **Recoveries**: Debt recovery and credit settlements (`recovery_screen.dart`).

### 6. Reporting
- **Business Reports**: Various analytical reports (`reports_screen.dart`).
- **Report Printing**: Direct printing support for reports (`reports_printing_screen.dart`).

### 7. User & Role Management
- **Employees**: Manage staff members (`employee_list_screen.dart`).
- **Roles & Permissions**: Access control mapping (`roles_screen.dart`).
- **Shift Management**: Opening, closing, and tracking cash drawer shifts.

### 8. Settings & Administration
- **Business Setup**: Initial tenant configuration (`setup_business_screen.dart`).
- **Branch Management**: Multi-branch support (`branch_management_screen.dart`).
- **General Settings**: App preferences and configurations (`settings_screen.dart`).
- **Gift Cards**: Issue and manage gift card balances (`gift_cards_screen.dart`).

### 9. Authentication & Onboarding
- **Login/Signup**: Secure authentication flows (`login_screen.dart`, `signup_screen.dart`).
- **Onboarding**: First-time user experience (`onboarding_screen.dart`, `setup_profile_screen.dart`).

## Project Structure
- `lib/controllers`: Business logic and state management controllers.
- `lib/db`: Database helpers and schema definitions (`sqflite`).
- `lib/models`: Dart data models matching the database schema.
- `lib/providers`: State management providers (using `provider` package).
- `lib/screens`: UI screens grouped by feature.
- `lib/services`:
  - `api_service.dart`: HTTP client (Dio) with Authentication.
  - `sync_service.dart`: Logic to Push/Pull data from backend.
- `lib/utils`: Helper functions, constants, and formatting tools.
- `lib/widgets`: Reusable UI components.

## Configuration & Setup

### Permissions
The app requires **Camera** permission for scanning. This is configured in `android/app/src/main/AndroidManifest.xml`.

### API Configuration
Open `lib/services/api_service.dart` and update the `baseUrl` as needed:
```dart
// For Emulator
static const String baseUrl = 'http://10.0.2.2:8000/api';

// For Physical Device (same Wi-Fi)
static const String baseUrl = 'http://<your-local-ip>:8000/api';

// For Production
static const String baseUrl = 'https://pos.sata.pk/api';
```

### Running the App
```bash
# Get dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

### Building APK
```bash
flutter build apk --release
```

## Further Documentation
- [Stock Management Process](STOCK_MANAGEMENT.md): Detailed overview of how inventory, batches, and price variants are handled.
