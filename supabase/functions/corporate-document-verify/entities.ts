/** Irish / multinational enterprise patterns + CRO registration markers. */
export const ENTITY_PATTERNS: RegExp[] = [
  /\bCRO\s*(?:No\.?|Number|#)?\s*[:#]?\s*\d{5,8}\b/i,
  /\bCompanies Registration Office\b/i,
  /\bRegistered (?:in|with) Ireland\b/i,
  /\b(?:Ltd\.?|Limited|PLC|pl\.?c\.?|Designated Activity Company|DAC)\b/i,
  /\b(Google|Microsoft|Amazon|Meta|Apple|Deloitte|PwC|KPMG|Ernst\s*&\s*Young|EY|Accenture|IBM|Oracle|Salesforce|Stripe|Shopify|HubSpot|Workday|Zendesk|Indeed|Intercom|Fidelity|Citadel|Mastercard|Visa)\b/i,
  /\b(AIB|Bank of Ireland|Revolut|Permanent TSB|Ulster Bank)\b/i,
  /\b(TCS|Tata Consultancy|Infosys|Wipro|HCL|Capgemini)\b/i,
];

export function hasWhitelistedEntity(text: string): boolean {
  return ENTITY_PATTERNS.some((pattern) => pattern.test(text));
}
