export interface OpenBankingMetadata {
  financial_verified: boolean;
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

export async function sealOpenBankingMetadata(
  payload: OpenBankingMetadata,
): Promise<string> {
  const secret = Deno.env.get("OPEN_BANKING_SEAL_SECRET") ??
    "dev-open-banking-seal-change-me";
  const key = await importSealKey(secret);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = new TextEncoder().encode(JSON.stringify(payload));
  const cipher = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, key, data);
  const combined = new Uint8Array(iv.byteLength + cipher.byteLength);
  combined.set(iv, 0);
  combined.set(new Uint8Array(cipher), iv.byteLength);
  return btoa(String.fromCharCode(...combined));
}
