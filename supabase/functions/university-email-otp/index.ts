import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";
import { isAllowedUniversityEmail, normalizeEmail } from "./domains.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OTP_TTL_MS = 10 * 60 * 1000;
const MAX_VERIFY_ATTEMPTS = 5;
const MIN_RESEND_MS = 60 * 1000;
const MAX_SENDS_PER_HOUR = 5;

type Action = "send" | "verify";

interface RequestBody {
  action?: Action;
  email?: string;
  code?: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function generateOtp(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}

async function hashOtp(email: string, otp: string): Promise<string> {
  const secret = Deno.env.get("UNIVERSITY_OTP_SECRET") ?? "dev-secret-change-me";
  const data = new TextEncoder().encode(`${secret}:${email}:${otp}`);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function sendEmail(to: string, otp: string): Promise<void> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    throw new Error("RESEND_API_KEY is not configured on Supabase Edge Functions.");
  }

  const from = Deno.env.get("OTP_FROM_EMAIL") ??
    "TrueCircle <onboarding@resend.dev>";

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from,
      to: [to],
      subject: "Your TrueCircle verification code",
      html: `
        <p>Your TrueCircle university email verification code is:</p>
        <p style="font-size:28px;font-weight:700;letter-spacing:4px">${otp}</p>
        <p>This code expires in 10 minutes. If you did not request this, ignore this email.</p>
      `,
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Email provider error (${response.status}): ${detail}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

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
  const email = body.email ? normalizeEmail(body.email) : "";
  const code = body.code?.trim() ?? "";

  if (action !== "send" && action !== "verify") {
    return jsonResponse({ error: "action must be send or verify." }, 400);
  }

  if (!email || !isAllowedUniversityEmail(email)) {
    return jsonResponse({
      error: "Use a valid Irish university email (.ac.ie or known college domain).",
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

  if (action === "send") {
    const now = Date.now();
    const { data: existing } = await admin
      .from("university_email_otps")
      .select("last_sent_at, send_count, created_at")
      .eq("user_id", userId)
      .eq("email", email)
      .maybeSingle();

    if (existing?.last_sent_at) {
      const lastSent = new Date(existing.last_sent_at).getTime();
      if (now - lastSent < MIN_RESEND_MS) {
        return jsonResponse({
          error: "Please wait a minute before requesting another code.",
        }, 429);
      }

      const hourAgo = now - 60 * 60 * 1000;
      const createdAt = new Date(existing.created_at).getTime();
      const sendCount = existing.send_count ?? 1;
      if (createdAt > hourAgo && sendCount >= MAX_SENDS_PER_HOUR) {
        return jsonResponse({
          error: "Too many codes sent. Try again in an hour.",
        }, 429);
      }
    }

    const otp = generateOtp();
    const otpHash = await hashOtp(email, otp);
    const expiresAt = new Date(now + OTP_TTL_MS).toISOString();

    const nextSendCount = existing
      ? (existing.send_count ?? 0) + 1
      : 1;

    const { error: upsertError } = await admin
      .from("university_email_otps")
      .upsert({
        user_id: userId,
        email,
        otp_hash: otpHash,
        expires_at: expiresAt,
        attempts: 0,
        send_count: nextSendCount,
        last_sent_at: new Date(now).toISOString(),
      }, { onConflict: "user_id,email" });

    if (upsertError) {
      console.error("OTP upsert failed:", upsertError);
      return jsonResponse({ error: "Could not store verification code." }, 500);
    }

    try {
      await sendEmail(email, otp);
    } catch (err) {
      console.error("Email send failed:", err);
      await admin
        .from("university_email_otps")
        .delete()
        .eq("user_id", userId)
        .eq("email", email);
      return jsonResponse({
        error: err instanceof Error ? err.message : "Could not send email.",
      }, 502);
    }

    return jsonResponse({ ok: true, expires_in_seconds: OTP_TTL_MS / 1000 });
  }

  // verify
  if (!/^\d{6}$/.test(code)) {
    return jsonResponse({ error: "Enter the 6-digit code from your email." }, 400);
  }

  const { data: row, error: fetchError } = await admin
    .from("university_email_otps")
    .select("otp_hash, expires_at, attempts")
    .eq("user_id", userId)
    .eq("email", email)
    .maybeSingle();

  if (fetchError || !row) {
    return jsonResponse({ error: "No active code for this email. Request a new one." }, 400);
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    await admin
      .from("university_email_otps")
      .delete()
      .eq("user_id", userId)
      .eq("email", email);
    return jsonResponse({ error: "Code expired. Request a new one." }, 400);
  }

  if ((row.attempts ?? 0) >= MAX_VERIFY_ATTEMPTS) {
    return jsonResponse({ error: "Too many attempts. Request a new code." }, 429);
  }

  const expectedHash = await hashOtp(email, code);
  if (expectedHash !== row.otp_hash) {
    await admin
      .from("university_email_otps")
      .update({ attempts: (row.attempts ?? 0) + 1 })
      .eq("user_id", userId)
      .eq("email", email);
    return jsonResponse({ error: "Invalid code." }, 400);
  }

  await admin
    .from("university_email_otps")
    .delete()
    .eq("user_id", userId)
    .eq("email", email);

  return jsonResponse({ ok: true, verified: true, email });
});
