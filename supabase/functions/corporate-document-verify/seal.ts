export interface VerificationMetadata {
  employment_verified: boolean;
  verification_track: string;
  timestamp: string;
}

async function importSealKey(secret: string): Promise<CryptoKey> {
  const material = new TextEncoder().encode(secret.padEnd(32, "0").slice(0, 32));
  return crypto.subtle.importKey(
    "raw",
    material,
    { name: "AES-GCM" },
    false,
    ["encrypt"],
  );
}

/** AES-GCM seal for trust metadata — no document content is encrypted or stored. */
export async function sealVerificationMetadata(
  payload: VerificationMetadata,
): Promise<string> {
  const secret = Deno.env.get("CORPORATE_VERIFY_SEAL_SECRET") ??
    "dev-seal-secret-change-in-production";
  const key = await importSealKey(secret);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = new TextEncoder().encode(JSON.stringify(payload));
  const cipher = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, data);
  const combined = new Uint8Array(iv.byteLength + cipher.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(cipher), iv.byteLength);
  return btoa(String.fromCharCode(...combined));
}
