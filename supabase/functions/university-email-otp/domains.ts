// Keep in sync with lib/utils/irish_university_domains.dart

const SUFFIXES = [".ac.ie"];

const HOSTS = [
  "ucd.ie",
  "ucdconnect.ie",
  "tcd.ie",
  "mydit.ie",
  "mu.ie",
  "mumail.ie",
  "dcu.ie",
  "mytudublin.ie",
  "tudublin.ie",
  "ul.ie",
  "studentmail.ul.ie",
  "nuigalway.ie",
  "ucc.ie",
  "student.ucc.ie",
  "maynoothuniversity.ie",
  "setu.ie",
  "lit.ie",
  "ait.ie",
  "dkit.ie",
  "student.dkit.ie",
  "rcsi.ie",
  "rcsi.com",
  "griffith.ie",
  "ncirl.ie",
];

export function isAllowedUniversityEmail(email: string): boolean {
  const normalized = email.trim().toLowerCase();
  const at = normalized.lastIndexOf("@");
  if (at <= 0 || at === normalized.length - 1) return false;

  const domain = normalized.substring(at + 1);
  if (SUFFIXES.some((suffix) => domain.endsWith(suffix))) return true;
  for (const host of HOSTS) {
    if (domain === host || domain.endsWith(`.${host}`)) return true;
  }
  return false;
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}
