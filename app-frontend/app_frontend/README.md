# app_frontend

تم فصل التطبيق إلى نسختين مستقلتين:

- `operations`: تطبيق المعتمدين والوكلاء
- `admin`: تطبيق الأدمن

كل نسخة لها:

- مسار دخول مختلف
- جلسة تخزين منفصلة
- `applicationId` مختلف على Android (يمكن تثبيتهما معًا على نفس الجهاز)

## التشغيل (Debug)

من داخل مجلد `app-frontend/app_frontend`:

```bash
flutter run --flavor operations -t lib/main_operations.dart
flutter run --flavor admin -t lib/main_admin.dart
```

## البناء (Android)

APK:

```bash
flutter build apk --flavor operations -t lib/main_operations.dart
flutter build apk --flavor admin -t lib/main_admin.dart
```

App Bundle:

```bash
flutter build appbundle --flavor operations -t lib/main_operations.dart
flutter build appbundle --flavor admin -t lib/main_admin.dart
```

## Android IDs

- `operations`: `com.radical.moneytransfer.operations`
- `admin`: `com.radical.moneytransfer.admin`
