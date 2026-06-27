/// Read-once liquidity proof checks for Irish Open Banking AIS payloads.
abstract final class OpenBankingLiquidityValidator {
  /// Dublin platform floor — recurring salary or liquid balance signal.
  static const defaultMinMonthlySalaryEur = 1200.0;
  static const defaultMinCurrentBalanceEur = 2000.0;

  static bool meetsPlatformCapability({
    required double? currentBalanceEur,
    required bool recurringSalaryDetected,
    double? monthlySalaryEur,
    int? userBudgetMinEur,
    double minMonthlySalaryEur = defaultMinMonthlySalaryEur,
    double minCurrentBalanceEur = defaultMinCurrentBalanceEur,
  }) {
    final salary = monthlySalaryEur ?? 0;
    final balance = currentBalanceEur ?? 0;

    if (recurringSalaryDetected && salary >= minMonthlySalaryEur) {
      return true;
    }

    if (balance >= minCurrentBalanceEur) {
      return true;
    }

    if (userBudgetMinEur != null && userBudgetMinEur > 0) {
      final budgetFloor = userBudgetMinEur * 0.85;
      if (recurringSalaryDetected && salary >= budgetFloor) return true;
      if (balance >= budgetFloor) return true;
    }

    return false;
  }

  static String failureMessage({
    int? userBudgetMinEur,
  }) {
    if (userBudgetMinEur != null && userBudgetMinEur > 0) {
      return 'Your linked account does not yet show income or balance signals '
          'that match your stated rental budget. Try again after your next salary '
          'deposit, or connect a primary current account.';
    }
    return 'Your linked account does not yet show sufficient recurring salary '
        'or current balance for platform verification. Try your primary current '
        'account or check back after your next salary deposit.';
  }
}
