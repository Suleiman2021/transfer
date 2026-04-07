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
}
