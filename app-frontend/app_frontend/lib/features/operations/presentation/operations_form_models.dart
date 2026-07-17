class OperationsTransferRequest {
  const OperationsTransferRequest({
    required this.fromCashboxId,
    required this.toCashboxId,
    required this.amount,
    required this.operationType,
    this.note,
    this.commissionPercent,
    this.sourceCurrency = 'SYP',
  });

  final String fromCashboxId;
  final String toCashboxId;
  final String amount;
  final String operationType;
  final String? note;
  final String? commissionPercent;
  final String sourceCurrency;
}
