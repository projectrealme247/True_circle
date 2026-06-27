import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RequestBody {
  code?: string;
  redirect_uri?: string;
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
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
  const clientId = Deno.env.get("LINKEDIN_CLIENT_ID");
  const clientSecret = Deno.env.get("LINKEDIN_CLIENT_SECRET");

  if (!supabaseUrl || !supabaseAnonKey) {
    return jsonResponse({ error: "Supabase environment is not configured." }, 500);
  }

  if (!clientId || !clientSecret) {
    return jsonResponse({
      error: "LINKEDIN_CLIENT_ID and LINKEDIN_CLIENT_SECRET are not configured.",
    }, 500);
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

  const code = body.code?.trim() ?? "";
  const redirectUri = body.redirect_uri?.trim() ?? "";

  if (!code || !redirectUri) {
    return jsonResponse({ error: "code and redirect_uri are required." }, 400);
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return jsonResponse({ error: "Sign in required." }, 401);
  }

  const tokenResponse = await fetch("https://www.linkedin.com/oauth/v2/accessToken", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "authorization_code",
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
    }),
  });

  const tokenJson = await tokenResponse.json();
  if (!tokenResponse.ok) {
    console.error("LinkedIn token error:", tokenJson);
    return jsonResponse({
      error: tokenJson.error_description ?? "LinkedIn authorization failed.",
    }, 400);
  }

  const accessToken = tokenJson.access_token?.toString();
  if (!accessToken) {
    return jsonResponse({ error: "LinkedIn did not return an access token." }, 502);
  }

  const profileResponse = await fetch("https://api.linkedin.com/v2/userinfo", {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  const profileJson = await profileResponse.json();
  if (!profileResponse.ok) {
    console.error("LinkedIn userinfo error:", profileJson);
    return jsonResponse({ error: "Could not load LinkedIn profile." }, 502);
  }

  return jsonResponse({
    ok: true,
    profile: {
      sub: profileJson.sub ?? "",
      name: profileJson.name ?? "",
      email: profileJson.email ?? "",
      picture: profileJson.picture ?? "",
      email_verified: profileJson.email_verified === true,
    },
  });
});
