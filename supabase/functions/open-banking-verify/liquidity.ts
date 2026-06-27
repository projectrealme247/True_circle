export const OpenBankingLiquidityValidator = {
  defaultMinMonthlySalaryEur: 1200,
  defaultMinCurrentBalanceEur: 2000,

  meetsPlatformCapability(input: {
    currentBalanceEur?: number;
    recurringSalaryDetected: boolean;
    monthlySalaryEur?: number;
    userBudgetMinEur?: number;
  }): boolean {
    const salary = input.monthlySalaryEur ?? 0;
    const balance = input.currentBalanceEur ?? 0;

    if (input.recurringSalaryDetected && salary >= this.defaultMinMonthlySalaryEur) {
      return true;
    }
    if (balance >= this.defaultMinCurrentBalanceEur) {
      return true;
    }
    if (input.userBudgetMinEur && input.userBudgetMinEur > 0) {
      const floor = input.userBudgetMinEur * 0.85;
      if (input.recurringSalaryDetected && salary >= floor) return true;
      if (balance >= floor) return true;
    }
    return false;
  },

  failureMessage(budgetMin?: number): string {
    if (budgetMin && budgetMin > 0) {
      return "Your linked account does not yet show income or balance signals that match your stated rental budget. Try again after your next salary deposit, or connect a primary current account.";
    }
    return "Your linked account does not yet show sufficient recurring salary or current balance for platform verification. Try your primary current account or check back after your next salary deposit.";
  },
};
