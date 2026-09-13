# Landlord decision engine — usability testing

**Status:** Layout frozen. Decision states + Applicant Passport shipped.  
**Do not start:** Offer Workflow · Tenancy Due Diligence — until this test pass is done and findings reviewed.

## Scope under test

Surface: `/landlord-dashboard` decision engine (3-col workspace).

| State | How to reach (mock) | Expected Col 3 |
|-------|---------------------|----------------|
| **Recommended** | Smithfield → Siobhán / Aoife (invited) · Docklands → Nina · Rathmines → Ciara | Chip RECOMMENDED · “Why recommended” · Invite viewing + Message · Passport |
| **Needs Review** | Smithfield → James / Priya / Marco · Docklands → David / Ellen / Sam · Rathmines → Ben | Chip NEEDS REVIEW · “Why review” · Invite anyway + Message · amber mismatch when relevant |
| **Viewing Invited** | Smithfield → Aoife Byrne | Chip VIEWING INVITED · “Why invited” · Message applicant (primary) · Resend invite |
| **Not Suitable** | Smithfield → Tom Walsh · Rathmines → Lisa Nguyen | Chip NOT SUITABLE · “Why not suitable” · Dismiss + Message · decline styling |
| **Empty** | Listing with zero applicants (or clear selection if added later) | Title + short body — no CTAs |

Passport (same green slot for every selected applicant): trust tier, ID/income, languages, household / commute or stability bullet.

## Script (20–25 min with a Dublin host)

1. **Orient** — Without coaching, ask: “What are you supposed to do on this screen?”
2. **Strong fit** — “Invite your strongest applicant.” Note time-to-action and CTA clarity.
3. **Needs review** — “This one is uncertain — what would you do?” Check if Invite anyway feels safe.
4. **Already invited** — Open Aoife. “What happens next?” Check Message vs Resend.
5. **Not suitable** — Open Tom or Lisa. “Would you accidentally invite them?” Check chip + Dismiss.
6. **Passport** — “What do you know about this person without leaving the pane?”
7. **Cohorts** — Col 1 Strong Fits / Needs Review / Not Suitable — do counts match intuition?
8. **Empty** — (if available) “What would you do with an empty queue?”

## Pass criteria (gate before Offer / Due Diligence)

- [ ] Hosts name the primary job as “who to invite next” (not CRM admin)
- [ ] Not Suitable is never mistaken for Needs Review
- [ ] Viewing Invited does not feel like a fresh invite path
- [ ] Passport answers trust / ID / income without leaving Col 3
- [ ] No request to change column layout or nav before next milestone

## Findings log

| # | Date | Participant | Finding | Severity | Action |
|---|------|-------------|---------|----------|--------|
| 1 | | | | | *Pending first session* |

## Explicit stop line

After filling the findings log from at least **3 landlord sessions** (or internal walkthrough + 1 external host), review whether Offer Workflow or Tenancy Due Diligence is next. Do **not** implement those workflows in the same pass as this test.
