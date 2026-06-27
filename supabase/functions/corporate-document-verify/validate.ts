import { hasWhitelistedEntity } from "./entities.ts";

export const VERIFICATION_YEAR = 2026;

export interface ValidationResult {
  ok: boolean;
  error?: string;
}

export function normalizeName(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

/** Requires meaningful name tokens from the Universal Human Core full_name. */
export function identityMatches(profileName: string, extractedText: string): boolean {
  const tokens = normalizeName(profileName)
    .split(" ")
    .filter((t) => t.length > 1);

  if (tokens.length === 0) {
    return false;
  }

  const haystack = normalizeName(extractedText);
  const required = tokens.length >= 2
    ? [tokens[0], tokens[tokens.length - 1]]
    : tokens;

  return required.every((token) => haystack.includes(token));
}

/** Contract must reference active 2026 employment dates — reject legacy-only docs. */
export function hasActiveContractYear(text: string, year = VERIFICATION_YEAR): boolean {
  const normalized = text.replace(/\s+/g, " ");
  const yearStr = String(year);

  if (!normalized.includes(yearStr)) {
    return false;
  }

  const legacyYears = ["2020", "2021", "2022", "2023", "2024", "2025"];
  const mentionsLegacy = legacyYears.some((y) => new RegExp(`\\b${y}\\b`).test(normalized));
  const mentionsCurrent = new RegExp(`\\b${yearStr}\\b`).test(normalized);

  if (mentionsLegacy && !mentionsCurrent) {
    return false;
  }

  const activePatterns = [
    new RegExp(`\\b(start|commence|commencing|effective|dated|as of|from)\\b[^.\\n]{0,48}\\b${yearStr}\\b`, "i"),
    new RegExp(`\\b(offer|employment|contract|appointment)\\b[^.\\n]{0,72}\\b${yearStr}\\b`, "i"),
    new RegExp(`\\b${yearStr}\\b\\s*[-–—to]+\\s*(202[6-9]|203\\d)\\b`, "i"),
    new RegExp(`\\b(january|february|march|april|may|june|july|august|september|october|november|december)\\b[^.\\n]{0,24}\\b${yearStr}\\b`, "i"),
    new RegExp(`\\b${yearStr}\\b[^.\\n]{0,24}\\b(january|february|march|april|may|june|july|august|september|october|november|december)\\b`, "i"),
  ];

  return activePatterns.some((pattern) => pattern.test(normalized));
}

export function validateCorporateDocument(
  extractedText: string,
  profileFullName: string,
): ValidationResult {
  const text = extractedText.trim();

  if (text.length < 40) {
    return {
      ok: false,
      error:
        "We could not read enough text from this document. Try a clearer PDF or export directly from your employer.",
    };
  }

  if (!identityMatches(profileFullName, text)) {
    return {
      ok: false,
      error:
        "The employee name on this document does not match your profile full name. Update your profile or upload a document issued to you.",
    };
  }

  if (!hasActiveContractYear(text)) {
    return {
      ok: false,
      error:
        "This document does not show an active employment or offer period for 2026. Please upload your current contract or offer letter.",
    };
  }

  if (!hasWhitelistedEntity(text)) {
    return {
      ok: false,
      error:
        "We could not confirm a registered company or employer on this document. Include your employer letterhead, Ltd/PLC designation, or CRO details.",
    };
  }

  return { ok: true };
}
