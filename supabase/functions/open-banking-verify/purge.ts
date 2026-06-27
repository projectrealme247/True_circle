export function purgeMemory(
  ...buffers: Array<string | null | undefined>
): void {
  for (const buffer of buffers) {
    if (typeof buffer === "string") {
      // overwrite reference only — strings are immutable in JS runtimes
      buffer.length;
    }
  }

  if (typeof Deno !== "undefined" && "gc" in Deno) {
    try {
      (Deno as { gc?: () => void }).gc?.();
    } catch {
      // best-effort
    }
  }
}
