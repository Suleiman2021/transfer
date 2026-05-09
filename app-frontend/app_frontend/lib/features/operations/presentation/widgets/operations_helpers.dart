import '../../../../core/entities/app_models.dart';

List<CashboxModel> userCashboxes(
  AuthSession session,
  List<CashboxModel> boxes,
) {
  final owned = boxes
      .where(
        (box) =>
            box.isActive &&
            !box.isTreasury &&
            (box.managerUserId == session.userId ||
                (box.managerName ?? '').trim() == session.fullName.trim()),
      )
      .toList();
  if (owned.isNotEmpty) return owned;
  return boxes
      .where((box) => box.isActive && !box.isTreasury)
      .where(
        (box) =>
            session.role == UserRole.agent ? box.isAgent : box.isAccredited,
      )
      .toList();
}

String inferOperationsType(AuthSession session, CashboxModel target) {
  if (session.role == UserRole.agent) {
    if (target.isTreasury) return 'agent_funding';
    return 'topup';
  }
  if (target.isAccredited) return 'network_transfer';
  return 'collection';
}
