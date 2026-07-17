class AppValidators {
  AppValidators._();

  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'اسم المستخدم مطلوب';
    if (v.length < 3) return 'اسم المستخدم قصير جداً';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'كلمة المرور مطلوبة';
    if (v.length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
    return null;
  }

  static String? amount(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'المبلغ مطلوب';
    final number = double.tryParse(raw.replaceAll(',', '.'));
    if (number == null) return 'أدخل مبلغاً صحيحاً';
    if (number <= 0) return 'المبلغ يجب أن يكون أكبر من صفر';
    return null;
  }

  static String? nonNegativeAmount(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'المبلغ مطلوب';
    final number = double.tryParse(raw.replaceAll(',', '.'));
    if (number == null) return 'أدخل مبلغاً صحيحاً';
    if (number < 0) return 'المبلغ يجب أن يكون صفراً أو أكبر';
    return null;
  }

  static String? percent(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'النسبة مطلوبة';
    final number = double.tryParse(raw.replaceAll(',', '.'));
    if (number == null) return 'أدخل نسبة صحيحة';
    if (number < 0 || number > 100) {
      return 'النسبة يجب أن تكون بين 0 و 100';
    }
    return null;
  }

  // Accepted formats (spaces/dashes ignored):
  //   09XXXXXXXX          → Syrian local (10 digits, starts with 09)
  //   +963 9XXXXXXXX      → Syrian international with +
  //   00963 9XXXXXXXX     → Syrian international with 00
  //   +[1-9]XX…           → Other international (7-15 digits after +/00)
  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'رقم الهاتف مطلوب';

    final digits = v.replaceAll(RegExp(r'[\s\-()]'), '');

    // Syrian local mobile: 09XXXXXXXX (exactly 10 digits, starts with 09)
    if (RegExp(r'^09\d{8}$').hasMatch(digits)) return null;

    // Syrian international: +9639XXXXXXXX or 009639XXXXXXXX
    if (RegExp(r'^(\+963|00963)9\d{8}$').hasMatch(digits)) return null;

    // Generic international: starts with + or 00 followed by 7–14 digits
    if (RegExp(r'^(\+|00)[1-9]\d{6,13}$').hasMatch(digits)) return null;

    return 'أدخل رقم موبايل صحيح\nمثال: 09XXXXXXXX أو +963 9XXXXXXXX';
  }
}
