# SmartParking Pocket 📱🚗

**Lightweight, Offline-First Mobile Parking Management & Theft Alert System for Local Attendants**

Built with **Flutter**, designed specifically for parking attendants in local municipal/commercial lots to manage vehicle check-in, check-out, fee calculation, stolen vehicle verification, and revenue tracking using only a smartphone camera and a handheld 58mm Bluetooth thermal printer.

---

## 🌟 Key Features

1. **On-Device Optical Character Recognition (OCR)**
   - Powered by **Google ML Kit Text Recognition SDK** running 100% offline.
   - Real-time license plate detection and automatic alphanumeric normalization (strips spaces, dashes, symbols).

2. **Theft Hotlist & Instant Siren Alerts**
   - Automatically cross-checks every detected license plate against the local `Stolen_Hotlist` database.
   - **If Stolen**: Triggers full-screen flashing red warning, pulsating phone vibration, loud emergency siren, and pre-formatted emergency SMS dispatch to the owner/police.

3. **Offline-First SQLite Database**
   - Full ACID transaction compliance via `sqflite`.
   - Purges active sessions from `Vehicles_Parked` into permanent `Parking_History` ledger on checkout.

4. **Bluetooth ESC/POS Thermal Printing (58mm)**
   - Generates compact receipts for low-cost 58mm handheld Bluetooth POS printers.
   - Automatically encodes ticket session IDs into raster bitmap QR codes (`GS v 0`) for rapid exit verification.

5. **Flexible Tariff & Pricing Engine**
   - Grace period support (free exit under N minutes).
   - Configurable Flat Rate (e.g. for bikes) or Hourly Slab billing (e.g. for cars).

6. **Lost Ticket Recovery**
   - Instant search across active sessions by full or partial license plate number, allowing checkout without physical paper ticket.

7. **Shift Handover & WhatsApp Summary**
   - Attendant closing shift reconciliation: cash in drawer vs digital QR collected.
   - 1-Tap export to WhatsApp with pre-filled message directly addressed to the parking lot owner.

---

## 🏗️ Architecture & Database Schema

```
lib/
├── core/
│   ├── theme/           # AppTheme (High-contrast outdoor sunlight styling)
│   └── utils/           # AppPrefs (Shared preferences for lot info & rates)
├── data/
│   ├── datasources/     # local_db.dart (SQLite schemas, indexes, and initial seeds)
│   ├── models/          # VehicleParked, ParkingHistory, StolenHotlist, AttendantShift, RatesConfig
│   └── repositories/    # ParkingRepository, HotlistRepository, ShiftRepository, RatesRepository
├── services/
│   ├── ocr_service.dart               # Google ML Kit offline text extraction & plate regex
│   ├── theft_alert_service.dart       # Siren audio, emergency vibration, SMS intent
│   ├── esc_pos_printer_service.dart   # ESC/POS byte generator & Bluetooth thermal printing
│   ├── pricing_service.dart           # Grace period & slab fee calculation
│   └── whatsapp_service.dart          # Formatted shift report generator & WhatsApp launcher
└── presentation/
    ├── screens/
    │   ├── home_screen.dart           # Live occupancy counter & guard quick actions
    │   ├── scan_entry_screen.dart     # Camera OCR viewfinder, plate entry & ticket print
    │   ├── scan_exit_screen.dart      # OCR exit checkout, auto-fee, cash/QR toggle
    │   ├── lost_ticket_screen.dart    # Active session plate search & recovery
    │   ├── theft_hotlist_screen.dart  # Stolen vehicle hotlist management & siren test
    │   ├── analytics_screen.dart      # Daily/Weekly revenue split & peak hours chart
    │   ├── shift_screen.dart          # Shift reconciliation & WhatsApp report export
    │   ├── rates_settings_screen.dart # Vehicle tariff and lot capacity configuration
    │   └── printer_settings_screen.dart # Bluetooth thermal printer scanner & test print
    └── widgets/
        ├── stolen_alert_dialog.dart   # Full-screen red alert modal
        └── receipt_preview_dialog.dart # Visual 58mm paper receipt preview
```

### Database Tables (SQLite)
* `Vehicles_Parked`: `session_id` (PK), `vehicle_number` (Indexed), `vehicle_type`, `entry_timestamp`, `attendant_id_entry`, `status`
* `Parking_History`: `history_id` (PK), `session_id`, `vehicle_number`, `vehicle_type`, `entry_timestamp`, `exit_timestamp`, `duration_minutes`, `fee_charged`, `payment_mode`, `attendant_id_exit`
* `Stolen_Hotlist`: `stolen_id` (PK), `vehicle_number` (Unique, Indexed), `fir_number`, `owner_contact`, `date_added`, `is_active`
* `Attendant_Shifts`: `shift_id` (PK), `attendant_name`, `start_time`, `end_time`, `cash_collected`, `digital_collected`, `status`
* `Rates_Config`: `vehicle_type` (PK), `base_fee`, `pricing_model`, `grace_period_mins`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>= 3.19.0)
- Android Studio / Xcode
- Physical Android or iOS device (recommended for testing camera OCR and Bluetooth thermal printer)

### Installation
```bash
# Clone the repository
git clone <repo-url>
cd "SmartParking Pocket"

# Install Flutter dependencies
flutter pub get

# Run unit tests
flutter test

# Run on connected mobile device
flutter run
```

### Building Release APK
```bash
flutter build apk --release
```

---

## 🖨️ Recommended Thermal Printer Hardware
- Any standard **58mm Mini Portable Bluetooth Thermal Receipt Printer** (ESC/POS compatible).
- Common models: PT-210, MPT-II, POS-5802, GOOJPRT.
- Standard baud rate: 9600. Paper width: 58mm (384 dots per line).

---

## 🛡️ License
100% Free and Open Source under the MIT License. Zero paid third-party APIs required.
