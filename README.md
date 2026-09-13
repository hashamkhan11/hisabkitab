# HisabShare

A shared expense/ledger tracking app for Android and iOS, built with Flutter. HisabShare lets people organize contacts into categories, record credit/debit transactions against each contact, and — its core feature — share a contact's ledger with another HisabShare user so both sides see the same running balance in real time, with an accept/reject workflow for transactions raised by the other party.

Backend: [hisabkitab-api](../hisabkitab-api) (Laravel).

## Features

- **Firebase Authentication** — email/password sign-up with email verification enforced before login, plus login by mobile number (resolved to the linked email server-side).
- **Categories & contacts** — organize people into custom categories (e.g. Friends, Business, Family), each with its own running balance.
- **Transaction ledger** — record credit/debit entries per contact with a date, amount, and note; running balance and a full transaction history per contact.
- **Shared ledgers** — share a contact with another registered user by email; the recipient sees the same ledger and can raise transactions that the owner must accept or reject before they post.
- **Notifications** — in-app notification center for share invites and transaction requests, with swipe-to-delete, multi-select bulk delete, and "clear all"; polling-based live updates plus push notifications via Firebase Cloud Messaging.
- **Statement export** — export a contact's transaction history to CSV or PDF, share it via the OS share sheet, or email it as a PDF attachment (sent server-side through Resend).
- **Quick transaction FAB** — record a transaction against any contact in two taps from the home screen, with guided empty-states if no category/contact exists yet.
- **Light & dark theme** — a custom Material 3 theme with a dedicated light/dark color system (see `lib/theme/app_theme.dart`), togglable from Settings and persisted locally.
- **Crash reporting** — Firebase Crashlytics wired into both the Flutter error zone and platform-level uncaught errors.

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart SDK ^3.6) |
| Auth | Firebase Authentication |
| Push notifications | Firebase Cloud Messaging |
| Crash reporting | Firebase Crashlytics |
| Media storage | Firebase Storage (profile pictures) |
| Routing | go_router |
| State management | provider (ChangeNotifier) |
| Local persistence | shared_preferences |
| PDF generation | pdf + printing |
| Backend API | REST, consumed via a thin `http`-based `ApiClient` (see `lib/services/api_client.dart`) |

## Architecture

```
lib/
├── main.dart                # App entrypoint, Firebase init, routing, providers
├── models/                  # Plain data models
├── providers/                # ChangeNotifier state: current user, contacts, theme
├── repositories/             # API-backed data access, one per resource (categories,
│                              contacts, notifications, statements, users, summary)
├── services/                  # Cross-cutting services: API client, local cache,
│                              polling, push notifications, PDF/CSV export
├── screens/                   # Top-level pages (auth, home, contact detail, settings, ...)
├── widgets/                    # Reusable UI components and bottom sheets
└── theme/                      # App-wide color/typography system
```

The app talks to a Laravel REST API for all durable data (categories, contacts, transactions, notifications); Firebase is used only for authentication, push delivery, file storage, and crash telemetry. Real-time-feeling updates (e.g. incoming notifications) are done via short-interval polling rather than a persistent socket, since the traffic volumes involved don't justify the added infrastructure.

## Getting started

### Prerequisites

- Flutter SDK (3.6 or newer)
- A Firebase project with Authentication, Cloud Messaging, Storage, and Crashlytics enabled
- A running instance of [hisabkitab-api](../hisabkitab-api)

### Setup

```bash
flutter pub get
```

Add your own Firebase config:
- `android/app/google-services.json` for Android
- `ios/Runner/GoogleService-Info.plist` for iOS

Point the app at your backend by setting the API base URL used in `lib/services/api_client.dart`.

### Run

```bash
flutter run
```

### Tests & static analysis

```bash
flutter analyze
flutter test
```

### Build a release APK

```bash
flutter build apk --release
```

## License

Proprietary — all rights reserved.
