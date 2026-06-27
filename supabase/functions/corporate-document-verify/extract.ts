import { extractText, getDocumentProxy } from "npm:unpdf@0.12.1";

const MAX_BYTES = 8 * 1024 * 1024; // 8 MB in-memory cap

export function detectMime(bytes: Uint8Array, fileName: string): string {
  if (bytes.length >= 4 && bytes[0] === 0x25 && bytes[1] === 0x50 && bytes[2] === 0x44 && bytes[3] === 0x46) {
    return "application/pdf";
  }
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }
  if (bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47) {
    return "image/png";
  }

  const lower = fileName.toLowerCase();
  if (lower.endsWith(".pdf")) return "application/pdf";
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) return "image/jpeg";
  if (lower.endsWith(".png")) return "image/png";
  return "application/octet-stream";
}

/** In-memory text extraction — never writes to disk or object storage. */
export async function extractDocumentText(
  bytes: Uint8Array,
  fileName: string,
): Promise<string> {
  if (bytes.byteLength === 0) {
    throw new Error("The uploaded file appears empty.");
  }
  if (bytes.byteLength > MAX_BYTES) {
    throw new Error("File is too large. Please upload a document under 8 MB.");
  }

  const mime = detectMime(bytes, fileName);

  if (mime === "application/pdf") {
    const pdf = await getDocumentProxy(bytes);
    const { text } = await extractText(pdf, { mergePages: true });
    return text.join("\n");
  }

  if (mime === "image/jpeg" || mime === "image/png") {
    return extractEmbeddedAscii(bytes);
  }

  throw new Error(
    "Unsupported format. Upload a PDF, JPG, or PNG employment contract or offer letter.",
  );
}

/** Best-effort ASCII sweep for scanned exports without persisting image buffers. */
function extractEmbeddedAscii(bytes: Uint8Array): string {
  const chunks: string[] = [];
  let current = "";

  for (let i = 0; i < bytes.length; i++) {
    const code = bytes[i];
    const isPrintable = (code >= 32 && code <= 126) || code === 10 || code === 13 || code === 9;
    if (isPrintable) {
      current += String.fromCharCode(code);
      if (current.length >= 120) {
        chunks.push(current);
        current = "";
      }
    } else if (current.length >= 6) {
      chunks.push(current);
      current = "";
    } else {
      current = "";
    }
  }

  if (current.length >= 6) chunks.push(current);
  return chunks.join(" ");
}
