/// Allowlisted Irish university email domains for Track A verification.
abstract final class IrishUniversityDomains {
  static const suffixes = ['.ac.ie'];

  static const hosts = [
    'ucd.ie',
    'ucdconnect.ie',
    'tcd.ie',
    'mydit.ie',
    'mu.ie',
    'mumail.ie',
    'dcu.ie',
    'mytudublin.ie',
    'tudublin.ie',
    'ul.ie',
    'studentmail.ul.ie',
    'nuigalway.ie',
    'ucc.ie',
    'student.ucc.ie',
    'maynoothuniversity.ie',
    'mumail.ie',
    'setu.ie',
    'lit.ie',
    'ait.ie',
    'dkit.ie',
    'student.dkit.ie',
    'rcsi.ie',
    'rcsi.com',
    'griffith.ie',
    'ncirl.ie',
  ];

  /// Returns true when [email] belongs to a known Irish university domain.
  static bool isAllowedUniversityEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final at = normalized.lastIndexOf('@');
    if (at <= 0 || at == normalized.length - 1) return false;

    final domain = normalized.substring(at + 1);
    if (suffixes.any(domain.endsWith)) return true;
    for (final host in hosts) {
      if (domain == host || domain.endsWith('.$host')) return true;
    }

    return false;
  }

  /// Masked display e.g. `s***@ucdconnect.ie`.
  static String maskEmail(String email) {
    final normalized = email.trim();
    final at = normalized.indexOf('@');
    if (at <= 1) return normalized;
    final local = normalized.substring(0, at);
    final domain = normalized.substring(at);
    final visible = local.length <= 2 ? local[0] : local.substring(0, 2);
    return '$visible***$domain';
  }
}
