# Offline Money Tracker — Flutter

Minimal, fully offline expense + loan tracker.

## Included

- Expenses tab
- Loans tab
- Expense add/edit/delete
- Expense notes
- Expense totals
- Loan amount + monthly payment
- Loan tenure
- Start/due dates
- Loan notes
- 5/4/3/2/1-day reminders
- Due-today reminder
- Daily overdue reminders until marked paid
- Mark paid / mark unpaid
- Local SQLite database
- Local Android notifications
- No Firebase
- No Supabase
- No login
- No cloud
- No analytics
- No internet/API code

## Dependencies

Current stable packages used in this project:

- flutter_local_notifications 22.3.1
- sqflite 2.4.4+1
- timezone 0.11.1
- intl 0.20.2
- path 1.9.1

This set requires a modern Flutter/Dart toolchain. The current notification package requires Flutter 3.38.1+ and sqflite 2.4.4+1 requires Dart 3.12+.

## Setup

1. Create/open a Flutter project.
2. Copy the `lib/` folder from this package into the project.
3. Merge the dependencies from `pubspec.yaml` into your project's pubspec.
4. Run:

   flutter pub get

5. Apply `android/AndroidManifest.additions.xml` to your AndroidManifest.xml.
6. Apply `android/build.gradle.kts.additions.txt` to your Android app Gradle configuration.
7. Make sure Android compileSdk is at least 35.
8. Run:

   flutter clean
   flutter pub get
   flutter run

## Notification behavior

For an unpaid loan with a due date:

- 5 days before: reminder
- 4 days before: reminder
- 3 days before: reminder
- 2 days before: reminder
- 1 day before: reminder
- due date: due-today reminder
- after due date: daily overdue reminder at approximately 9:00 AM

The overdue reminder is scheduled as a daily repeating local notification. Marking the loan as paid cancels all notification IDs belonging to that loan.

The app uses inexact Android scheduling intentionally. This avoids requiring exact-alarm permission. Notifications may therefore arrive slightly around the scheduled time.

## Important

The notification timezone is set to Asia/Kolkata in:

lib/services/notification_service.dart

If this app is used outside India, change that timezone.

## Database

The SQLite database is created automatically on first launch:

money_tracker.db

No network connection is used by the application code.
