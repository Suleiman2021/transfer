// لا تُشغّل أو تبنِ هذا الملف مباشرة: التطبيق مقسوم لنسختين مستقلتين ولكل
// منهما نقطة دخول خاصة. تشغيل هذا الملف بالخطأ (مثلاً بنسيان -t) ينتج نسخة
// operations لكن بهوية/اسم admin أو العكس. استخدم:
//   flutter run   --flavor operations -t lib/main_operations.dart
//   flutter run   --flavor admin      -t lib/main_admin.dart
//   flutter build apk --flavor operations -t lib/main_operations.dart
//   flutter build apk --flavor admin      -t lib/main_admin.dart

void main() {
  throw UnsupportedError(
    'lib/main.dart ليست نقطة دخول صالحة لهذا التطبيق.\n'
    'استخدم -t lib/main_operations.dart --flavor operations\n'
    'أو    -t lib/main_admin.dart --flavor admin',
  );
}
