# Professional UI Overhaul — Implementation Tasks

All tasks descend from ACs in `spec.md`.

## Task 1: Upgrade ThemeProvider (radii, shadows, decoration helpers, button style, input polish)

**Priority:** high
**Status:** pending
**Parent ACs:** Rule AC1, Rubric AC8, Rubric AC9

**Description:**
Upgrade `lib/providers/theme_provider.dart` systemically while preserving 100% existing signatures.
1. Update radius tokens: `radiusList=12`, `radiusCard=16`, `radiusInput=12`, `radiusGlass=16`
2. Add layered `cardShadow` getter (returns `List<BoxShadow>`) — light/dark aware
3. New `elevatedCardDecoration` getter: surface color + radiusCard + cardShadow + subtle 1px border (cardBorder)
4. New `statCardDecoration(List<Color>? colors, {Color? borderColor})` method: returns gradient-filled BoxDecoration with shadow, radiusCard, optional accent border
5. Upgrade existing `glassDecoration`: now uses elevatedCardDecoration style (still returns BoxDecoration, same name)
6. Upgrade `glassListDecoration`: tile-friendly elevated style (radiusList, lighter shadow)
7. Upgrade `glassInputDecoration`: increase internal padding (contentPadding 18 vertical, 16 horizontal), focused border 2.0px highlight, unfocused 1.0px divider
8. Upgrade `glassBackground`: returns Container decoration with true gradient bg (light: EEF2F7→FFFFFF ; dark: 050504→121210)
9. New `primaryButtonStyle` → ButtonStyle: filled highlight bg, foreground white, elevation=2, shadowColor, rounded shape radiusInput, padding 14h/14v, fontWeight 700, size 15 font
10. New `badgeDecoration(Color color, {bool hollow=false})` → BoxDecoration helper
11. Keep `gradientPrimary` etc. + new gradient presets for stat cards if missing (gradientInfo, gradientAmber, gradientRose)

**Test Requirements (TRs):**
- TR1 (rule): `GetDiagnostics` / `dart analyze` — zero new analyzer errors after edits
- TR2 (rule): ThemeProvider existing public methods compile without renames; old caller sites unchanged

**Completion Evidence:**
- Committed edit diff for theme_provider.dart with all items listed above

---

## Task 2: Redesign Login Screen (gradient bg, elevated auth card, quick login tiles)

**Priority:** high
**Status:** pending
**Parent ACs:** Rule AC2, Rule AC6, Rule AC7, Rubric AC8

**Description:**
Edit `lib/screens/login_screen.dart`.
1. Wrap Scaffold body in upgraded `theme.glassBackground()`
2. Center: `ConstrainedBox(maxWidth: 420)` → elevated card (24 radius) with padding 28
3. Title area: bold "Welcome Back" headline + "Login to continue" caption using textPrimary / textSecondary
4. Email / Password inputs: upgraded `glassInputDecoration`; password toggle icon styled consistently
5. Login button: apply `theme.primaryButtonStyle`, full width
6. Saved accounts quick-login section: "Quick Login" subhead → wrap each account in an elevated tile (theme.elevatedCardDecoration, radiusList) with tap highlight; profile name, email, PIN mask, delete icon
7. Keep `_showLoginForm` / `FadeTransition` animation logic intact; keep all handlers and API logic unchanged

**TRs:**
- TR1 (rule): Cold build + login flow still works (existing email/prefill preserved, quick-login flow, PIN dialog, all buttons)
- TR2 (rule): No RenderFlex overflow on 360px narrow screens

**Completion Evidence:**
- Screenshot-capable visual diff + analyzer clean

---

## Task 3: Home Dashboard Premium Stats & Module Cards

**Priority:** high
**Status:** pending
**Parent ACs:** Rule AC3, Rule AC6, Rule AC7, Rubric AC8, Rubric AC9

**Description:**
Edit `lib/screens/home_screen.dart` (stat card builder area + module grid/list area).
1. Identify the `_StatCard` / stat rendering section. Convert stats to `theme.statCardDecoration` with per-card gradients:
   - Products → `gradientPrimary`
   - Customers → `gradientAmber`
   - Deals → `gradientPurple`
   - Sales → `gradientSuccess`
   Or similar appropriate mapping using existing gradient presets.
2. Each stat card contains: icon in small circular tinted container, large bold number (font 24+, w800), caption label, trailing small arrow icon. Use elevated + gradient with white-on-gradient text if gradients are dark enough; otherwise textPrimary.
3. Module feature grid (if grid) or list (if list) section: apply `theme.elevatedCardDecoration` on each tile. Module icon in small tinted accent container; name textPrimary, subtitle "Tap to open" style in textSecondary.
4. AppBar top-right: sync icon with status text; use consistent badge chip for status.
5. Keep all `_handleModuleTap` navigation and `_loadStats` logic 100% unchanged.

**TRs:**
- TR1 (rule): Stat count numbers match DB values (no changes to counting queries)
- TR2 (rule): Every module tap opens the same screen as before
- TR3 (rubric 1-5): Cards score ≥4 premium look vs previous version

**Completion Evidence:**
- Visual check + analyzer clean; dashboard grid tiles tap handlers unchanged

---

## Task 4: POS Product/Deal Tiles + Cart Section + Category Chips Upgrade

**Priority:** high
**Status:** pending
**Parent ACs:** Rule AC4, Rule AC6, Rule AC7, Rubric AC8, Rubric AC9

**Description:**
Edit 4 widget files in `lib/widgets/pos/`:
1. **pos_product_grid.dart** — `_buildDealTile`: replace container decoration with `theme.elevatedCardDecoration` + subtle highlight gradient on bottom section; icon in center; ensure overflow protection (already using Flexible/FittedBox, keep that); InkWell borderRadius=16, splash highlight color with Opacity 0.2
2. **pos_product_tile.dart** — apply same elevated tile + rounded corners + InkWell clipping with radius 16; thumbnail area tint accent gradient
3. **pos_category_selector.dart** — selected category → gradient background + elevated shadow + text white/ bold; unselected → elevated outlined tile (outlined with divider border); active tab indicator removed if redundant
4. **pos_cart_section.dart** / **pos_cart_item_tile.dart** — cart header: card shape elevation; each tile elevated; quantity badge use theme.badgeDecoration; plus/minus tap buttons use theme.primaryButtonStyle mini

Additionally `lib/screens/pos_screen.dart` top bar: search bar as elevated pill input, top action buttons as elevated chips with shadow.

**TRs:**
- TR1 (rule): No RenderFlex overflow in 3-col / 4-col / 6-col grids (use widget inspector check)
- TR2 (rule): Tapping a product/deal still adds item to cart as before
- TR3 (rule): Category selector still filters products correctly
- TR4 (rule): Cart item add/remove still works, total correct

**Completion Evidence:**
- POS visual run-through; overflow clean; all interactions preserve behavior

---

## Task 5: Add Product Form — Grouped Elevated Section Cards

**Priority:** medium
**Status:** pending
**Parent ACs:** Rule AC5, Rule AC6, Rule AC7, Rubric AC9

**Description:**
Edit `lib/screens/add_product_screen.dart` (and similar forms where applicable — keep scope to Add Product as representative).
1. Wrap Column children in sectional groups inside `Container(decoration: theme.elevatedCardDecoration)` with padding 16. Group headings in bold ("Basic Information", "Pricing", "Stock & Inventory", "Taxes & Discounts").
2. Each field uses upgraded `glassInputDecoration`. Dropdowns (category, brand, unit) wrap in consistent input height containers.
3. Save button: `theme.primaryButtonStyle` full width bottom fixed or scrollable bottom area. Cancel secondary button TextButton style.
4. Keep form key validation, all handlers, barcode scanner, _controller.* flow unchanged.

**TRs:**
- TR1 (rule): Form validation still triggers correctly (required fields, barcode uniqueness error)
- TR2 (rule): `onSave` → success snack + pop return true as before
- TR3 (rule): Unit dropdown includes all new volume/bottle units (verifies previous units task still intact)

**Completion Evidence:**
- Analyzer clean; form saves successfully

---

## Task 6: Product List Screen — Polished Tiles + Search Pill + Empty State

**Priority:** medium
**Status:** pending
**Parent ACs:** Rule AC6, Rule AC7, Rubric AC8, Rubric AC9

**Description:**
Edit `lib/screens/product_list_screen.dart`.
1. Search input at top: pill-shaped elevated search bar with prefix icon; use contentPadding 14h/14v; apply input decoration upgrade
2. Each list tile uses `glassListDecoration` — icon in tinted left container, title bold, subtitle with stock/qty + unit info, trailing edit/delete as chip buttons
3. Inactive view toggle: styled segmented/filter chip row using elevated outlined chips
4. Empty state: icon in large gradient circle with caption; primary styled "Add Product" CTA button
5. Keep expand/collapse groupings and all data loading logic untouched

**TRs:**
- TR1 (rule): Products still load, search filters work, edit tap still opens add/edit screen
- TR2 (rule): Inactive toggle still filters correctly

**Completion Evidence:**
- Visual polish + analyzer clean; all interactions preserved

---

## Task 7: Build / Analyze & Final Sanity Run

**Priority:** high
**Status:** pending
**Parent ACs:** Rule AC1, Rule AC7

**Description:**
1. Run `flutter pub get` (if needed; no new packages)
2. Run `flutter analyze` via IDE diagnostics or command
3. Do a cold build of the Windows/desktop target
4. Smoke test: login → dashboard → POS (tap deal/product tile → cart) → Add Product form → Product list
5. Toggle theme: verify light/dark both look polished
6. Fix any analyzer issues or runtime RenderFlex issues discovered

**TRs:**
- TR1 (rule): `GetDiagnostics` returns zero errors
- TR2 (rule): `flutter analyze` reports zero new issues introduced by the UI changes
- TR3 (rubric 0-5): Overall professional aesthetic ≥ 4 (see spec)

**Completion Evidence:**
- Diagnostics output + manual smoke test result notes

---

## Summary Coverage Map

| AC | Covered By Tasks |
|---|---|
| Rule AC1 (API stable) | Task 1, Task 7 |
| Rule AC2 (Login) | Task 2 |
| Rule AC3 (Home stats) | Task 3 |
| Rule AC4 (POS tiles) | Task 4 |
| Rule AC5 (Form inputs) | Task 5 |
| Rule AC6 (Light+Dark) | Task 1–7 all |
| Rule AC7 (No behavior change) | Task 2–6 explicit, Task 7 verified |
| Rubric AC8 (Aesthetic ≥4) | All, evaluated in Task 7 |
| Rubric AC9 (Cohesion ≥4) | All, evaluated in Task 7 |
