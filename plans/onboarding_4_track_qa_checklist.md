# 4-Track QA Checklist

Use this checklist during manual app validation. For each track, capture:

- `Track`
- `Route visited`
- `Expected visible fields`
- `Unexpected fields seen`
- `Prefill result`
- `Sync-back result`
- `Pass/Fail`

Recommended terminal log template:

```text
[QA] Track=<track> Step=<screen> Result=<pass|fail> Notes="<short note>"
```

Example:

```text
[QA] Track=LandlordSharedSpace Step=AddListing/Step1 Result=pass Notes="Location, languages, house rules pruned into read-only cards"
```

## Track 1: Seeker Entire Place

### Onboarding
- Enter via `What brings you to True Circle?` -> `I'm looking for a place`
- Select `Space track` -> `Entire Place`
- Verify page 1 shows:
  - `Email`
  - `Full name`
  - `Current Location / Base`
  - `Mother Tongue`
  - `Languages Spoken`
- Verify page 1 does not show:
  - `Property Neighborhood / Area`
  - `Property Eircode`
  - `House rules`
  - `Current household composition`

### Step 2
- Verify it shows only entire-place seeker content:
  - `Budget`
  - `Primary Commuter Route`
  - optional `Secondary Commuter Route` for multi-person household
  - `Home setup`
  - `Environment preferences`
  - `Lease & household (entire place)`
  - `Roots & trust`
- Verify it does not show:
  - `Shared flat filters`
  - `Shared living preferences`
  - `Roommate setup`
  - `Native place / roots` duplicated elsewhere

### Feed inheritance
- Save onboarding and land on `/`
- Verify default filter state inherits:
  - `budgetMax`
  - `preferredLeaseMonths`
  - `moveInWindow`
- Verify commute-aware ranking still runs

## Track 2: Seeker Shared Space

### Onboarding
- Entry: `I'm looking for a place`
- `Space track` -> `Shared Space`
- Verify page 1 still only asks core identity/location/languages once

### Step 2
- Verify it shows only shared-space seeker content:
  - `Budget` with shared-space copy
  - `Primary Commuter Route`
  - `Roommate setup`
  - `Shared-space compatibility`
  - `Roots & trust`
- Verify it does not show:
  - `Lease & household (entire place)`
  - `Environment preferences`
  - family-specific entire-place fields
  - secondary commute priority UI unless explicitly intended

### Matcher inheritance
- Save and land on `/`
- Verify inherited defaults can influence:
  - `occupantType`
  - `genderPreference`
  - shared-space ranking context

## Track 3: Landlord Entire Place

### Onboarding
- Entry: `I have a space to rent`
- `Space track` -> `Entire Place`
- Verify page 1 shows:
  - `Email`
  - `Full name`
  - `Contact phone`
  - `Identity / Company name`
  - `Property Neighborhood / Area`
  - `Property Eircode`
  - `Listing defaults` -> `Property is furnished`
  - language fields
- Verify it does not show:
  - seeker commute fields
  - seeker budgets
  - `Current Location / Base`
  - roommate house rules

### Listing prefill
- Continue to `/add-listing`
- Verify read-only/pruned cards appear for:
  - `Location inherited from profile`
  - `Furnishing inherited from profile`
- Verify editable duplicates are hidden until `Edit ...` is pressed

### Publish sync-back
- Unlock and change furnishing or location
- Publish
- Verify saved profile session updates listing seed fields

## Track 4: Landlord Shared Space

### Onboarding
- Entry: `I have a space to rent`
- `Space track` -> `Shared Space`
- Verify page 1 shows:
  - `Contact phone`
  - `Identity / Company name`
  - `Property Neighborhood / Area`
  - `Property Eircode`
  - `Current household composition`
  - `House rules`
  - language fields
- Verify it does not show:
  - seeker budgets
  - seeker commute vectors
  - `Current Location / Base`
  - entire-place lease/income fields

### Listing prefill
- Continue to `/add-listing`
- Verify read-only/pruned cards appear for:
  - `Location inherited from profile`
  - `Household profile inherited`
  - `House rules inherited from profile`
- Verify editable duplicates are hidden until `Edit ...` is pressed

### Publish sync-back
- Unlock and modify shared-house fields
- Publish
- Verify profile host snapshot is updated with:
  - `languages`
  - `currentHouseholdMakeup`
  - `houseRules`
  - `listingSeed.propertyNeighborhood`
  - `listingSeed.propertyEircode`

## Cross-Track Regression Checks

- Back arrow works on all onboarding steps
- Intent splitter appears only on step 1
- Passport preview updates in real time
- Provider passport does not show `Current Base`
- No repeated questions across onboarding and listing creation
- No duplicate language chips
- No duplicate location prompts
- Switching tracks mid-onboarding does not leave stale fields visible
