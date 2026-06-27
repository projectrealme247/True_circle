/** Mandatory in-memory eviction — zero file bytes and OCR buffers after processing. */
export function purgeMemory(
  ...buffers: Array<Uint8Array | string | null | undefined>
): void {
  for (const buffer of buffers) {
    if (buffer instanceof Uint8Array) {
      buffer.fill(0);
    }
  }

  if (typeof Deno !== "undefined" && "gc" in Deno) {
    try {
      (Deno as { gc?: () => void }).gc?.();
    } catch {
      // gc is best-effort only
    }
  }
}
