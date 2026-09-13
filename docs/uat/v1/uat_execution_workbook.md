# TrueCircle V1 — UAT Execution Workbook

**Status:** Schema frozen for V1 execution  
**Inputs:** Frozen seeker dataset · ~50 Shared Living listings · ~50 Independent Places listings  
**Artifacts:**

| File | Purpose |
|------|---------|
| [`uat_execution_record.schema.json`](./uat_execution_record.schema.json) | Per-seeker execution record (JSON Schema 2020-12) |
| [`uat_dashboard_summary.schema.json`](./uat_dashboard_summary.schema.json) | Aggregated dashboard summary object |
| This workbook | CSV columns, pass/fail formulas, empty templates |

Marketplace separation is strict: `shared_living` seekers only see Shared Living listings; `independent_places` seekers only see Independent Places listings. Sentinel seekers `SL-MARKET-01` / `IP-MARKET-01` are dedicated bleed checks.

Do **not** regenerate the frozen seeker dataset as part of execution; copy reference fields (`uat_expected_result`, `uat_validation_points`, `expected_match_volume`) into each execution row when useful.

---

## 1. Execution record fields

Required execution fields (see JSON schema for types):

| Field | Notes |
|-------|--------|
| `seeker_id` | From frozen dataset |
| `uat_scenario` | From frozen dataset |
| `marketplace` | `shared_living` \| `independent_places` |
| `matches_returned` | Integer ≥ 0 |
| `marketplace_correct` | `Y` \| `N` |
| `top_5_listing_ids` | Array ≤ 5 ids (JSON) or pipe-joined in CSV |
| `card_review.understood_in_5_seconds` | `Y` \| `N` \| `null` if no matches |
| `card_review.key_facts_visible` | `Y` \| `N` \| `null` if no matches |
| `card_review.trust_visible` | `Y` \| `N` \| `null` if no matches |
| `detail_page_review.key_questions_answered` | `Y` \| `N` \| `null` if no matches |
| `detail_page_review.match_explanation_helpful` | `Y` \| `N` \| `null` if no matches |
| `detail_page_review.missing_information` | Free text; `""` if none |
| `contact_intent.would_apply` | `Y` \| `N` \| `null` if no matches |
| `severity` | `none` \| `low` \| `medium` \| `critical` |
| `finding` | Free text; `""` if none |
| `recommended_action` | Free text; `""` if none |

Optional reference / tooling fields:

| Field | Notes |
|-------|--------|
| `uat_expected_result` | `PASS` \| `LIMITED_MATCHES` \| `ZERO_MATCHES` (from frozen dataset) |
| `uat_validation_points` | Checklist strings from frozen dataset |
| `expected_match_volume` | `many` \| `few` \| `none` |
| `executed_at` | ISO-8601 |
| `executor` | Reviewer or automation id |
| `derived.*` | Optional boolean flags mirroring formulas below |

### Y/N encoding

Use string `"Y"` / `"N"` (not booleans) so CSV and JSON stay aligned. Use JSON `null` (CSV blank cell) for N/A when `matches_returned == 0`.

---

## 2. Pass / fail derivation rules

These rules feed the dashboard. Optional `derived.*` on each record should match them.

### Match volume OK (`match_volume_ok`)

Requires `uat_expected_result` on the record (copy from frozen dataset).

| `uat_expected_result` | Pass when |
|-----------------------|-----------|
| `PASS` | `matches_returned >= 5` (healthy set against ~50-listing inventory) |
| `LIMITED_MATCHES` | `1 <= matches_returned <= 4` |
| `ZERO_MATCHES` | `matches_returned == 0` |

If `uat_expected_result` is missing, treat `match_volume_ok` as failed for scenario scoring (do not guess).

### Per-record boolean checks

| Check | Pass condition | N/A |
|-------|----------------|-----|
| **Marketplace separation** | `marketplace_correct == "Y"` | Never N/A |
| **Card pass** | All of `understood_in_5_seconds`, `key_facts_visible`, `trust_visible` == `"Y"` | All three null when `matches_returned == 0` |
| **Detail pass** | `key_questions_answered == "Y"` **AND** `match_explanation_helpful == "Y"` | Both null when `matches_returned == 0` |
| **Contact intent yes** | `would_apply == "Y"` | null when `matches_returned == 0` |
| **Critical finding** | `severity == "critical"` (count, not a pass rate) | — |

`missing_information` does **not** fail detail pass by itself; capture gaps in text and raise `severity` when warranted.

### Scenario pass (`scenario_pass`)

A seeker scenario **passes** only when **all** of:

1. `match_volume_ok == true` (table above)
2. `marketplace_correct == "Y"`
3. `severity != "critical"`

Card, detail, and contact intent are reported separately and do **not** gate `scenario_pass`. That keeps matching/volume/marketplace outcomes distinct from UX review rates.

### Empty-state guidance (`ZERO_MATCHES` / `matches_returned == 0`)

- Leave card / detail Y/N / contact as blank/`null` (excluded from those rate denominators).
- Still set `marketplace_correct` (`Y` if empty state is correctly scoped to the seeker's marketplace).
- Still set `severity`, `finding`, `recommended_action` (e.g. wrong empty copy → `medium`/`critical`).
- `top_5_listing_ids` must be empty.

### Severity guidance (non-exhaustive)

| Severity | Examples |
|----------|----------|
| `critical` | Cross-marketplace listing in feed; crash; apply to wrong marketplace; unsafe/false match explanation |
| `medium` | Wrong empty state; systematically missing key facts; ranking nonsense for sentinel |
| `low` | Minor copy/layout issues; single missing soft fact |
| `none` | No notable issue |

---

## 3. CSV column structure

One row per seeker. Nested objects flattened with clear prefixes.

### Header row (copy into spreadsheet)

```text
seeker_id,uat_scenario,marketplace,uat_expected_result,expected_match_volume,uat_validation_points,matches_returned,marketplace_correct,top_5_listing_ids,card_understood_in_5_seconds,card_key_facts_visible,card_trust_visible,detail_key_questions_answered,detail_match_explanation_helpful,detail_missing_information,contact_would_apply,severity,finding,recommended_action,executed_at,executor,derived_marketplace_separation_pass,derived_card_pass,derived_detail_pass,derived_contact_intent_yes,derived_is_critical,derived_match_volume_ok,derived_scenario_pass
```

### Column list

| CSV column | Source |
|------------|--------|
| `seeker_id` | record |
| `uat_scenario` | record |
| `marketplace` | record |
| `uat_expected_result` | frozen reference |
| `expected_match_volume` | frozen reference (optional) |
| `uat_validation_points` | frozen reference; join with ` \| ` |
| `matches_returned` | record |
| `marketplace_correct` | `Y`/`N` |
| `top_5_listing_ids` | join with ` \| ` (max 5) |
| `card_understood_in_5_seconds` | `Y`/`N`/blank |
| `card_key_facts_visible` | `Y`/`N`/blank |
| `card_trust_visible` | `Y`/`N`/blank |
| `detail_key_questions_answered` | `Y`/`N`/blank |
| `detail_match_explanation_helpful` | `Y`/`N`/blank |
| `detail_missing_information` | free text |
| `contact_would_apply` | `Y`/`N`/blank |
| `severity` | enum |
| `finding` | free text |
| `recommended_action` | free text |
| `executed_at` | optional |
| `executor` | optional |
| `derived_marketplace_separation_pass` | `TRUE`/`FALSE` (optional; formula-filled) |
| `derived_card_pass` | `TRUE`/`FALSE`/blank |
| `derived_detail_pass` | `TRUE`/`FALSE`/blank |
| `derived_contact_intent_yes` | `TRUE`/`FALSE`/blank |
| `derived_is_critical` | `TRUE`/`FALSE` |
| `derived_match_volume_ok` | `TRUE`/`FALSE` |
| `derived_scenario_pass` | `TRUE`/`FALSE` |

### Empty template guidance

1. Paste the header row as row 1.
2. Pre-fill identity + reference columns from the frozen seeker dataset (`seeker_id`, `uat_scenario`, `marketplace`, `uat_expected_result`, `expected_match_volume`, `uat_validation_points`).
3. Leave execution columns empty until the run (`matches_returned` onward).
4. Leave `derived_*` empty if a script will compute them after export; or add spreadsheet formulas matching §2.
5. Suggested filename: `uat_execution_results_v1.csv` (do not commit secrets; results may stay local).

### Example empty JSON record

```json
{
  "seeker_id": "SL-STU-01",
  "uat_scenario": "Student · private room · medium budget · early move · Luas",
  "marketplace": "shared_living",
  "uat_expected_result": "PASS",
  "expected_match_volume": "many",
  "uat_validation_points": [
    "Shared Living listings only",
    "No marketplace bleed",
    "Private room displayed",
    "Availability visible",
    "Why-card includes room or timing reason"
  ],
  "matches_returned": 0,
  "marketplace_correct": "Y",
  "top_5_listing_ids": [],
  "card_review": {
    "understood_in_5_seconds": null,
    "key_facts_visible": null,
    "trust_visible": null
  },
  "detail_page_review": {
    "key_questions_answered": null,
    "match_explanation_helpful": null,
    "missing_information": ""
  },
  "contact_intent": {
    "would_apply": null
  },
  "severity": "none",
  "finding": "",
  "recommended_action": ""
}
```

*(Placeholder zeros/nulls above illustrate shape only — replace with real execution values.)*

### Example filled JSON record (PASS scenario)

```json
{
  "seeker_id": "SL-STU-01",
  "uat_scenario": "Student · private room · medium budget · early move · Luas",
  "marketplace": "shared_living",
  "uat_expected_result": "PASS",
  "expected_match_volume": "many",
  "uat_validation_points": [
    "Shared Living listings only",
    "No marketplace bleed",
    "Private room displayed"
  ],
  "matches_returned": 12,
  "marketplace_correct": "Y",
  "top_5_listing_ids": ["sl-001", "sl-014", "sl-022", "sl-031", "sl-040"],
  "card_review": {
    "understood_in_5_seconds": "Y",
    "key_facts_visible": "Y",
    "trust_visible": "Y"
  },
  "detail_page_review": {
    "key_questions_answered": "Y",
    "match_explanation_helpful": "Y",
    "missing_information": ""
  },
  "contact_intent": {
    "would_apply": "Y"
  },
  "severity": "none",
  "finding": "",
  "recommended_action": "",
  "derived": {
    "marketplace_separation_pass": true,
    "card_pass": true,
    "detail_pass": true,
    "contact_intent_yes": true,
    "is_critical": false,
    "match_volume_ok": true,
    "scenario_pass": true
  }
}
```

---

## 4. Summary dashboard

### Metrics

Let \(R\) be the set of execution records in scope.  
Let \(R_m\) be records where `marketplace == m` (`shared_living` or `independent_places`).  
Let \(R^{\neq 0}\) be records with `matches_returned > 0` (eligible for card/detail/contact).

| Metric | Numerator | Denominator | Notes |
|--------|-----------|-------------|--------|
| **Marketplace Separation Pass Rate** | count(`marketplace_correct == "Y"`) | \|R\| | Always include all seekers |
| **Card Pass Rate** | count(card pass among \(R^{\neq 0}\)) | \|R≠0\| | Exclude zero-match rows |
| **Detail Page Pass Rate** | count(detail pass among \(R^{\neq 0}\)) | \|R≠0\| | Both detail Y fields required |
| **Contact Intent Rate** | count(`would_apply == "Y"` among \(R^{\neq 0}\)) | \|R≠0\| | Not a quality gate for scenario pass |
| **Critical Findings Count** | count(`severity == "critical"`) | — | Absolute count (also report by marketplace) |
| **Scenario Pass Rate** | count(`scenario_pass`) | \|R\| | Volume + marketplace + no critical |

When a denominator is 0, rate is `null` (display as `—`).

### Aggregation

Compute **overall** and **by_marketplace** (`shared_living`, `independent_places`) using the same formulas on \(R\) and \(R_m\).

Optional: **by_uat_expected_result** slices for `PASS` / `LIMITED_MATCHES` / `ZERO_MATCHES` with `scenario_pass_rate` and `match_volume_ok_rate`.

### Suggested summary JSON shape

See [`uat_dashboard_summary.schema.json`](./uat_dashboard_summary.schema.json). Example:

```json
{
  "meta": {
    "uat_version": "v1",
    "seeker_count": 68,
    "listing_inventory": {
      "shared_living": 50,
      "independent_places": 50
    },
    "generated_at": "2026-08-04T12:00:00Z"
  },
  "overall": {
    "seeker_count": 68,
    "marketplace_separation_pass_rate": { "numerator": 67, "denominator": 68, "rate": 0.985, "rate_pct": 98.5 },
    "card_pass_rate": { "numerator": 50, "denominator": 55, "rate": 0.909, "rate_pct": 90.9 },
    "detail_page_pass_rate": { "numerator": 48, "denominator": 55, "rate": 0.873, "rate_pct": 87.3 },
    "contact_intent_rate": { "numerator": 40, "denominator": 55, "rate": 0.727, "rate_pct": 72.7 },
    "critical_findings_count": 1,
    "scenario_pass_rate": { "numerator": 60, "denominator": 68, "rate": 0.882, "rate_pct": 88.2 }
  },
  "by_marketplace": {
    "shared_living": {
      "seeker_count": 34,
      "marketplace_separation_pass_rate": { "numerator": 34, "denominator": 34, "rate": 1.0, "rate_pct": 100 },
      "card_pass_rate": { "numerator": 25, "denominator": 28, "rate": 0.893, "rate_pct": 89.3 },
      "detail_page_pass_rate": { "numerator": 24, "denominator": 28, "rate": 0.857, "rate_pct": 85.7 },
      "contact_intent_rate": { "numerator": 20, "denominator": 28, "rate": 0.714, "rate_pct": 71.4 },
      "critical_findings_count": 0,
      "scenario_pass_rate": { "numerator": 30, "denominator": 34, "rate": 0.882, "rate_pct": 88.2 }
    },
    "independent_places": {
      "seeker_count": 34,
      "marketplace_separation_pass_rate": { "numerator": 33, "denominator": 34, "rate": 0.971, "rate_pct": 97.1 },
      "card_pass_rate": { "numerator": 25, "denominator": 27, "rate": 0.926, "rate_pct": 92.6 },
      "detail_page_pass_rate": { "numerator": 24, "denominator": 27, "rate": 0.889, "rate_pct": 88.9 },
      "contact_intent_rate": { "numerator": 20, "denominator": 27, "rate": 0.741, "rate_pct": 74.1 },
      "critical_findings_count": 1,
      "scenario_pass_rate": { "numerator": 30, "denominator": 34, "rate": 0.882, "rate_pct": 88.2 }
    }
  }
}
```

### Dashboard / CSV summary sections (suggested layout)

1. **Header** — UAT version, inventory sizes, generated_at, seeker_count  
2. **Overall KPI strip** — six metrics from the table above  
3. **By marketplace** — same six metrics for Shared Living vs Independent Places  
4. **By expected result** (optional) — scenario / volume pass for PASS vs LIMITED vs ZERO  
5. **Critical findings table** — filter `severity == critical` (seeker_id, marketplace, finding, recommended_action)  
6. **Scenario failures** — `derived_scenario_pass == FALSE` with volume vs marketplace vs severity reason  

---

## 5. Assumptions (explicit)

1. **Healthy match threshold for `PASS`:** `matches_returned >= 5`. Tune only with product approval if inventory or ranking changes.
2. **Limited band:** `1–4` inclusive maps to `LIMITED_MATCHES`.
3. **Scenario pass** ignores card/detail/contact so matching correctness stays separate from UX scores.
4. **Zero-match rows** are excluded from card, detail, and contact denominators; they remain in marketplace and scenario denominators.
5. **Y/N are strings** (`"Y"`/`"N"`) for spreadsheet friendliness.
6. Frozen seeker dataset lives outside this folder until checked in; execution tooling should join by `seeker_id`.
