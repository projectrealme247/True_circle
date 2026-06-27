import { OpenBankingLiquidityValidator } from "./liquidity.ts";

export function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function identityAnchorMatches(
  profileFullName: string,
  bankHolderName: string,
): boolean {
  const tokens = normalizeName(profileFullName)
    .split(" ")
    .filter((t) => t.length > 1);
  if (tokens.length === 0) return false;

  const haystack = normalizeName(bankHolderName);
  const required = tokens.length >= 2
    ? [tokens[0], tokens[tokens.length - 1]]
    : tokens;

  return required.every((token) => haystack.includes(token));
}

export interface AisLiquiditySlice {
  current_balance_eur?: number;
  recurring_salary_detected?: boolean;
  monthly_salary_eur?: number;
}

export interface AisReadOncePayload {
  account_holder_name: string;
  liquidity: AisLiquiditySlice;
  institution?: string;
}

export function validateAisReadOnce(
  payload: AisReadOncePayload,
  profileFullName: string,
  budgetMin?: number,
): { ok: true } | { ok: false; error: string } {
  const holder = payload.account_holder_name?.trim() ?? "";
  if (!holder) {
    return {
      ok: false,
      error: "Your bank did not return an account holder name. Try your primary current account.",
    };
  }

  if (!identityAnchorMatches(profileFullName, holder)) {
    return {
      ok: false,
      error:
        "The account holder name from your bank does not match your profile full name. Update your profile or link the account registered in your name.",
    };
  }

  const liquidity = payload.liquidity ?? {};
  const liquidityOk = OpenBankingLiquidityValidator.meetsPlatformCapability({
    currentBalanceEur: liquidity.current_balance_eur,
    recurringSalaryDetected: liquidity.recurring_salary_detected === true,
    monthlySalaryEur: liquidity.monthly_salary_eur,
    userBudgetMinEur: budgetMin,
  });

  if (!liquidityOk) {
    return {
      ok: false,
      error: OpenBankingLiquidityValidator.failureMessage(budgetMin),
    };
  }

  return { ok: true };
}
