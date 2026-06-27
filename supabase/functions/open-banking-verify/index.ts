import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import {
  buildAuthorizeUrl,
  exchangeAuthorizationCode,
  fetchAisReadOnce,
  mockAisPayload,
  revokeAccessToken,
} from "./provider.ts";
import { purgeMemory } from "./purge.ts";
import { sealOpenBankingMetadata } from "./seal.ts";
import { validateAisReadOnce } from "./validate.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

type Action = "authorize" | "complete";

interface RequestBody {
  action?: Action;
  institution?: string;
  redirect_uri?: string;
  code?: string;
  state?: string;
  full_name?: string;
  budget_min?: number;
}

const ALLOWED_INSTITUTIONS = new Set([
  "ie_aib_ais",
  "ie_boi_ais",
  "ie_revolut_ais",
]);

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function randomState(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function isoDateStamp(): string {
  return new Date().toISOString().slice(0, 10);
}

async function resolveProfileName(
  admin: ReturnType<typeof createClient>,
  userId: string,
  hintedName: string,
): Promise<string> {
  const { data: row } = await admin
    .from("user_trust_profiles")
    .select("full_name")
    .eq("user_id", userId)
    .maybeSingle();

  const stored = row?.full_name?.trim();
  if (stored) return stored;

  const cleanHint = hintedName.trim();
  if (cleanHint) {
    await admin.from("user_trust_profiles").upsert({
      user_id: userId,
      full_name: cleanHint,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id" });
    return cleanHint;
  }

  return "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const mockMode = (Deno.env.get("OPEN_BANKING_MOCK") ?? "false") === "true";

  if (!supabaseUrl || !supabaseAnonKey || !serviceRoleKey) {
    return jsonResponse({ error: "Supabase environment is not configured." }, 500);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return jsonResponse({ error: "Sign in required." }, 401);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body." }, 400);
  }

  const action = body.action;
  const institution = body.institution?.trim() ?? "";
  const redirectUri = body.redirect_uri?.trim() ?? "";

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Sign in required." }, 401);
  }

  const userId = userData.user.id;

  if (action === "authorize") {
    if (!ALLOWED_INSTITUTIONS.has(institution)) {
      return jsonResponse({ error: "Choose AIB, Bank of Ireland, or Revolut." }, 400);
    }
    if (!redirectUri) {
      return jsonResponse({ error: "Missing redirect URI." }, 400);
    }

    const state = randomState();
    const authUrl = mockMode
      ? `${redirectUri}?code=mock-ais-code&state=${state}`
      : buildAuthorizeUrl({ institution, redirectUri, state });

    return jsonResponse({ ok: true, auth_url: authUrl, state, institution });
  }

  if (action !== "complete") {
    return jsonResponse({ error: "action must be authorize or complete." }, 400);
  }

  const code = body.code?.trim() ?? "";
  const fullNameHint = body.full_name?.trim() ?? "";
  const budgetMin = typeof body.budget_min === "number" ? body.budget_min : undefined;

  if (!code) {
    return jsonResponse({ error: "Missing bank authorization code." }, 400);
  }

  let accessToken: string | null = null;
  let aisPayload = null as ReturnType<typeof mockAisPayload> | null;

  try {
    const admin = createClient(supabaseUrl, serviceRoleKey);
    const profileFullName = await resolveProfileName(admin, userId, fullNameHint);
    if (!profileFullName) {
      return jsonResponse({
        error: "Add your full name under Profile before linking your bank.",
      }, 400);
    }

    if (mockMode || code === "mock-ais-code") {
      aisPayload = mockAisPayload(profileFullName, institution || undefined);
    } else {
      if (!redirectUri) {
        return jsonResponse({ error: "Missing redirect URI." }, 400);
      }
      accessToken = await exchangeAuthorizationCode({ code, redirectUri });
      aisPayload = await fetchAisReadOnce(accessToken, institution || undefined);
    }

    const validation = validateAisReadOnce(aisPayload, profileFullName, budgetMin);
    if (!validation.ok) {
      return jsonResponse({ error: validation.error }, 422);
    }

    const timestamp = isoDateStamp();
    const metadata = {
      financial_verified: true,
      verification_track: "Open Banking Track",
      timestamp,
    };
    const seal = await sealOpenBankingMetadata(metadata);

    const { error: updateError } = await admin
      .from("user_trust_profiles")
      .upsert({
        user_id: userId,
        full_name: profileFullName,
        trust_tier: "Grand",
        trust_stage: 2,
        financial_verified: true,
        verification_track: metadata.verification_track,
        open_banking_verification_seal: seal,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    if (updateError) {
      console.error("Open banking trust update failed:", updateError);
      return jsonResponse({
        error: "Verification succeeded but profile could not be updated. Try again shortly.",
      }, 500);
    }

    return jsonResponse({
      ok: true,
      verified: true,
      trust_tier: "Grand",
      trust_stage: 2,
      financial_verified: true,
      verification_track: metadata.verification_track,
      open_banking_verification_seal: seal,
      verified_at: timestamp,
      institution: institution || aisPayload.institution,
    });
  } catch (err) {
    console.error("Open banking verify failed:", err);
    const message = err instanceof Error
      ? err.message
      : "We could not verify your bank link. Try again shortly.";
    return jsonResponse({ error: message }, 422);
  } finally {
    if (accessToken) {
      await revokeAccessToken(accessToken);
    }
    purgeMemory(accessToken, code);
    accessToken = null;
    aisPayload = null;
  }
});
