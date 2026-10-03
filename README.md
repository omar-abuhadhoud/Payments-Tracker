# Payments Tracker

Payments Tracker is an offline Flutter app for recording income and expenses across multiple accounts. All data is kept on the device in a local SQLite database, and you can back it up to a file or restore it from one.

## Features

### Accounts

- Create, rename and delete accounts. A "Default Account" is created on first launch.
- Each account card shows its current balance, colored green when positive and red when negative.
- Search accounts by name.
- Sort accounts by balance, ascending or descending.
- Pin up to three accounts so they stay at the top of the list. Cards animate into their new position when you pin, unpin or re-sort.
- Deleting an account also deletes all of its transactions. You have to type "I am sure" before the delete goes through.
- An expandable **Total Overview** panel shows total income, total expense and net balance across all accounts.

### Account dashboard

Opening an account shows its overall balance and four actions:

| Action         | What it does                                                  |
| -------------- | ------------------------------------------------------------- |
| **Add**        | Record a new income or expense                                |
| **Log**        | Browse transactions day by day                                |
| **Monthly**    | View a month's totals and a per-day breakdown                 |
| **Date Range** | Get income, expense and net totals for any custom date range  |

### Recording transactions

- Choose Expense or Income, enter an amount and add an optional note.
- The amount field is validated. Income is stored as a positive value and expenses as a negative one.
- Existing transactions can be edited, including switching them between income and expense.

### Transactions log

- Shows one day at a time, with the date and time of each transaction and the running account balance after it.
- Swipe left or right, or use the bottom controls, to move between days that have transactions.
- Jump back to today, or pick a specific date from a date picker.
- Edit or delete any transaction (deletes ask for confirmation).

### Monthly summary

- Shows one month at a time. Swipe or use the bottom controls to move between months, or jump to the current month.
- A month picker lets you search by year, then by month, limited to months that contain transactions.
- An expandable **Monthly Details** panel shows the month's income, expense, net and the account balance at the end of the month. It hides while you scroll down and comes back when you scroll up.
- Below it, a card for each day with activity shows that day's net amount and the running balance. Tap a card to open **Daily Details**, which lists that day's transactions with a summary.

### Date range summary

- Pick any start and end date (defaults to the start of the current month through today).
- See total income, total expense and the net balance for that range.

### Backup, restore and reset

Available from the menu on the account list screen:

- **Create Backup** saves the full database to a `.db` file at a location you choose.
- **Restore Backup** replaces all current data with a previously saved backup, after a confirmation prompt.
- **Reset Data** clears all accounts and transactions. You have to type "I am sure" to confirm.

## Tech stack

| Area          | Choice                                         |
| ------------- | ---------------------------------------------- |
| Framework     | Flutter (Dart SDK ^3.8.1), Material design      |
| Database      | SQLite via `sqflite`                           |
| File access   | `file_picker`, `path_provider`, `path`         |
| Formatting    | `intl` for dates and number formatting         |
| App icons     | `flutter_launcher_icons`                       |

## Project structure

```
lib/
  main.dart                      App entry point and theme
  database/
    database_helper.dart         DB setup, schema migrations, backup/restore/reset
    tables/
      account_table.dart         Account queries, balances, pinning
      transaction_table.dart     Transaction CRUD and summary queries
  models/
    account_model.dart
    transaction_model.dart
  global_variables/
    app_colors.dart              Color palette
    chosen_account.dart          Currently selected account
  screens/
    choose_account_screen.dart   Account list, search, sort, pin, backup menu
    account_main_screen.dart     Account dashboard
    add_edit_transaction_screen.dart
    transactions_log_screen.dart
    monthly_summary_screen.dart
    daily_details_screen.dart
    date_range_summary_screen.dart
  widgets/                       Reusable cards, swipe navigation, drawers, helpers
```

## Data model

The database (`payment_tracker.db`, schema version 6) has two tables:

- **accounts**: `id`, `name`, `pinOrder` (null when the account is not pinned)
- **transactions**: `id`, `amount` (positive for income, negative for expense), `note`, `createdAt`, `accountId`

`transactions.accountId` references `accounts.id` with `ON DELETE CASCADE`, so removing an account removes its transactions. Balances are calculated from the transaction amounts rather than stored. Older databases are upgraded automatically when the app opens.

## Getting started

Prerequisites: the Flutter SDK (with Dart 3.8.1 or newer) and an Android or iOS device or emulator.

```bash
git clone <repository-url>
cd Payments-Tracker
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

To regenerate the launcher icons after changing `assets/icon/app_icon.png`:

```bash
dart run flutter_launcher_icons
```
