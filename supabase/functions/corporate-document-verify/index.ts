import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { extractDocumentText } from "./extract.ts";
import { purgeMemory } from "./purge.ts";
import { sealVerificationMetadata } from "./seal.ts";
import { validateCorporateDocument, VERIFICATION_YEAR } from "./validate.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const MAX_BYTES = 8 * 1024 * 1024;

interface RequestBody {
  file_base64?: string;
  file_name?: string;
  full_name?: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isoDateStamp(): string {
  return new Date().toISOString().slice(0, 10);
}

function decodeBase64File(encoded: string): Uint8Array {
  const binary = atob(encoded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
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
  const mockMode = (Deno.env.get("CORPORATE_VERIFY_MOCK") ?? "false") === "true";

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

  const fileName = body.file_name?.trim() || "document.pdf";
  const hintedName = body.full_name?.trim() ?? "";
  let fileBytes: Uint8Array | null = null;
  let extractedText: string | null = null;

  try {
    const encoded = body.file_base64?.trim();
    if (!encoded) {
      return jsonResponse({
        error: "No document received. Choose a PDF or image and try again.",
      }, 400);
    }

    fileBytes = decodeBase64File(encoded);
    if (fileBytes.byteLength > MAX_BYTES) {
      return jsonResponse({
        error: "File is too large. Please upload a document under 8 MB.",
      }, 400);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) {
      return jsonResponse({ error: "Sign in required." }, 401);
    }

    const userId = userData.user.id;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const profileFullName = await resolveProfileName(admin, userId, hintedName);
    if (!profileFullName) {
      return jsonResponse({
        error:
          "Add your full name under Profile before uploading a corporate document.",
      }, 400);
    }

    if (mockMode) {
      extractedText = [
        `Employment Offer Letter`,
        `Employee: ${profileFullName}`,
        `Employer: Example Ireland Ltd`,
        `CRO No. 123456`,
        `Effective date: 1 June ${VERIFICATION_YEAR}`,
        `Contract period: ${VERIFICATION_YEAR} to 2027`,
      ].join("\n");
    } else {
      extractedText = await extractDocumentText(fileBytes, fileName);
    }

    const validation = validateCorporateDocument(extractedText, profileFullName);
    if (!validation.ok) {
      return jsonResponse({ error: validation.error ?? "Verification could not be completed." }, 422);
    }

    const timestamp = isoDateStamp();
    const metadata = {
      employment_verified: true,
      verification_track: "Corporate Track",
      timestamp,
    };

    const seal = await sealVerificationMetadata(metadata);

    const { error: updateError } = await admin
      .from("user_trust_profiles")
      .upsert({
        user_id: userId,
        full_name: profileFullName,
        trust_tier: "Grand",
        trust_stage: 2,
        employment_verified: true,
        verification_track: metadata.verification_track,
        corporate_verification_seal: seal,
        updated_at: new Date().toISOString(),
      }, { onConflict: "user_id" });

    if (updateError) {
      console.error("Trust profile update failed:", updateError);
      return jsonResponse({
        error: "Verification succeeded but profile could not be updated. Try again shortly.",
      }, 500);
    }

    return jsonResponse({
      ok: true,
      verified: true,
      trust_tier: "Grand",
      trust_stage: 2,
      employment_verified: true,
      verification_track: metadata.verification_track,
      corporate_verification_seal: seal,
      verified_at: timestamp,
    });
  } catch (err) {
    console.error("Corporate verify failed:", err);
    const message = err instanceof Error
      ? err.message
      : "We could not process this document. Try a PDF export from your employer.";
    return jsonResponse({ error: message }, 422);
  } finally {
    purgeMemory(fileBytes, extractedText);
    fileBytes = null;
    extractedText = null;
  }
});
