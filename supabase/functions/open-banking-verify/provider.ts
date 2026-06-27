import type { AisReadOncePayload } from "./validate.ts";

const INSTITUTIONS: Record<string, string> = {
  ie_aib_ais: "Allied Irish Banks",
  ie_boi_ais: "Bank of Ireland",
  ie_revolut_ais: "Revolut",
};

export function institutionLabel(providerId?: string): string | undefined {
  if (!providerId) return undefined;
  return INSTITUTIONS[providerId];
}

export function buildAuthorizeUrl(input: {
  institution: string;
  redirectUri: string;
  state: string;
}): string {
  const apiBase = Deno.env.get("OPEN_BANKING_API_BASE") ??
    "https://api.truelayer-sandbox.com";
  const params = new URLSearchParams({
    response_type: "code",
    provider_id: input.institution,
    redirect_uri: input.redirectUri,
    state: input.state,
    scope: "accounts balance transactions:read",
  });
  return `${apiBase}/connect/authorize?${params.toString()}`;
}

/** Exchange auth code for access token — read-once, revoked after AIS pull. */
export async function exchangeAuthorizationCode(input: {
  code: string;
  redirectUri: string;
}): Promise<string> {
  const clientId = Deno.env.get("OPEN_BANKING_CLIENT_ID");
  const clientSecret = Deno.env.get("OPEN_BANKING_CLIENT_SECRET");
  const tokenUrl = Deno.env.get("OPEN_BANKING_TOKEN_URL") ??
    "https://auth.truelayer-sandbox.com/connect/token";

  if (!clientId || !clientSecret) {
    throw new Error("Open Banking provider credentials are not configured.");
  }

  const body = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: input.redirectUri,
    code: input.code,
  });

  const response = await fetch(tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Bank authorization could not be completed (${response.status}): ${detail}`);
  }

  const json = await response.json();
  const token = json.access_token?.toString();
  if (!token) {
    throw new Error("Bank authorization did not return an access token.");
  }
  return token;
}

/** Pull only account holder name + liquidity slice — discard full AIS response. */
export async function fetchAisReadOnce(
  accessToken: string,
  institution?: string,
): Promise<AisReadOncePayload> {
  const apiBase = Deno.env.get("OPEN_BANKING_API_BASE") ??
    "https://api.truelayer-sandbox.com";

  const accountsResponse = await fetch(`${apiBase}/data/v1/accounts`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (!accountsResponse.ok) {
    throw new Error("Could not read account identity from your bank.");
  }

  const accountsJson = await accountsResponse.json();
  const accounts = Array.isArray(accountsJson?.results)
    ? accountsJson.results
    : [];

  const primary = accounts[0];
  const holder = primary?.account_holder_name?.toString().trim() ??
    primary?.display_name?.toString().trim() ??
    "";

  let currentBalanceEur = 0;
  if (primary?.account_id) {
    const balanceResponse = await fetch(
      `${apiBase}/data/v1/accounts/${primary.account_id}/balance`,
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    if (balanceResponse.ok) {
      const balanceJson = await balanceResponse.json();
      const available = balanceJson?.results?.[0]?.available ??
        balanceJson?.results?.[0]?.current;
      currentBalanceEur = typeof available === "number" ? available : 0;
    }
  }

  const txResponse = await fetch(
    `${apiBase}/data/v1/accounts/${primary?.account_id ?? ""}/transactions`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );

  let recurringSalaryDetected = false;
  let monthlySalaryEur = 0;

  if (txResponse.ok) {
    const txJson = await txResponse.json();
    const txs = Array.isArray(txJson?.results) ? txJson.results : [];
    const credits = txs
      .filter((tx: Record<string, unknown>) => (tx.amount as number) > 0)
      .map((tx: Record<string, unknown>) => Math.abs(Number(tx.amount)))
      .filter((n: number) => n >= 800);

    if (credits.length >= 2) {
      recurringSalaryDetected = true;
      monthlySalaryEur = credits.reduce((a: number, b: number) => a + b, 0) /
        credits.length;
    }
  }

  return {
    account_holder_name: holder,
    liquidity: {
      current_balance_eur: currentBalanceEur,
      recurring_salary_detected: recurringSalaryDetected,
      monthly_salary_eur: monthlySalaryEur > 0 ? monthlySalaryEur : undefined,
    },
    institution,
  };
}

export async function revokeAccessToken(accessToken: string): Promise<void> {
  const revokeUrl = Deno.env.get("OPEN_BANKING_REVOKE_URL");
  if (!revokeUrl) return;

  try {
    await fetch(revokeUrl, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  } catch {
    // best-effort disconnect
  }
}

export function mockAisPayload(
  profileFullName: string,
  institution?: string,
): AisReadOncePayload {
  return {
    account_holder_name: profileFullName,
    liquidity: {
      current_balance_eur: 3500,
      recurring_salary_detected: true,
      monthly_salary_eur: 3200,
    },
    institution,
  };
}
