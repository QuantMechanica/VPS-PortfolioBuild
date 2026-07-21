# FTMO Campaign — Sourcing architecture + Wave-2 status (2026-07-21)

Consolidates the 2026-07-21 session: the sourcing-reach breakthrough, the info@ mailbox intake,
the mined findings, and the Wave-2 gate diagnoses. Companion to
`FTMO_CAMPAIGN_SYNTHESIS_2026-07-21.md` (the orthogonal 6-slot book) and
`FTMO_BOOK_ARCHITECTURE_2026-07-21.md`.

## 1. Sourcing reach — measured, not assumed

The binding campaign constraint is **new intraday carry-density**; sourcing feeds it. Reach from the
VPS was tested per source (evidence, not guessing):

| Source | Reader | Verdict (2026-07-21) |
|---|---|---|
| **Reddit** | **agy** (`agy -p "…" --dangerously-skip-permissions`, server-side web tool) | ✅ FETCHABLE — VPS-IP block bypassed. Codex/VPS `urllib` = 403 (blocked). Chrome browser also reads it (manual fallback). |
| **MQL5 CodeBase + Articles (index)** | Codex / agy direct HTTPS | ✅ FETCHABLE (200 OK). Concrete MQL5 pages had a transient TLS/HTTP2 close → UNRESOLVED, retry warranted. |
| **Forex Factory, BabyPips** | Chrome browser only | ⚠️ CHALLENGED — Cloudflare (`Just a moment` / `Attention Required`) 403 for both agy AND Codex. Needs an interactive browser session. |

**Routing rule:** Reddit + MQL5 → agy/Codex (headless, at scale) · Forex Factory + BabyPips /
Cloudflare sites → Chrome (Claude-in-Chrome, OWNER session) · analysis/build → Codex. Evidence:
`D:\QM\reports\state\mailbox_mining_20260721\FORUM_ACCESS_PROBE_2026-07-21.md`.

## 2. info@ mailbox intake (OWNER's forwarded links)

OWNER forwards research links from his phone to **info@quantmechanica.com**; `sourcing_intake_sweep.py`
(read-only IMAP, creds in `.private/secrets/imap_info_quantmechanica.json`) pulls them into
`D:\QM\reports\sourcing_intake\leads.csv`. A full read-only inventory (2026-07-21) found **140 unique
URLs** since Jan: 128 Reddit, 4 YouTube, 2 GitHub, 6 articles — splitting into two OWNER-intended
tracks: **~87 FTMO/trading** and **~40 AI-system/tooling** (r/ClaudeCode, r/codex, r/Agent_AI …).
Triaged in `mailbox_mining_20260721\{ROUTED_INVENTORY,TRACK_A_FTMO_shortlist,TRACK_B_AISYSTEM_notes}.md`.

## 3. Mined findings (FTMO-actionable)

- **#1 "10,000 FTMO challenges simulated" (r/Forex):** same profitable edge (50% WR, +1.5R/−1R, 5
  tr/day) gets funded 99.8% @ 0.5% risk vs 10% @ 3% risk; with shock losses (4%×−2.5R) 93% vs 5%.
  **Confirms density-first, not size-up** — you cannot size up to +10% without tripping the floor.
  → Two upgrades for `ftmo_p1_mc.py`: (a) inject a shock-loss tail; (b) add an outlier-strip
  robustness check to admission (strip top 5–10 winners; edge must survive). Detail:
  `mailbox_mining_20260721\REDDIT_MINING_FINDINGS_2026-07-21.md`.
- **agy's 3 top Reddit ideas** (doctrine-aligned): (1) **rolling correlation-cluster capping** (≥0.6
  → cap combined cluster risk to one 0.5% unit; protects FTMO daily DD — matches the cluster-caps
  roadmap); (2) **MAE/MFE expectancy exits** (track excursion distributions → statistical exits —
  ★unblocks the parked Exit-Surgery Tier B, which was waiting on MAE data); (3) **Deflated Sharpe
  gate** (DSR≥0.95, correlation-adjusted trial count — matches our N_eff-DSR doctrine).
- MQL5 mining shortlist: `mailbox_mining_20260721\MQL5_MINING_2026-07-21.md` (to review).
- agy's own FTMO *idea* (rollover spread-harvest) was rejected as an execution-artifact (violates
  limits-to-arbitrage doctrine + likely breaches FTMO prohibited-strategy rules). agy is strong at
  reading/collecting, weak at ideas — synthesis stays with Claude.

## 4. Wave-2 gate diagnoses (Codex, adjudicated by Claude)

- **QM5_13209 (Mulham PM sweep) → RETIRE.** Multiplicative attrition (sweep + 1.5×ATR + strict
  3-bar FVG + 1.5R + 50%-limit-fill) yields ~3 signals / 6 months; SP500 Q02 = 1 trade / PF 0.00 /
  −$452. The card's 70/yr cadence is internally inconsistent with the rules; no setfile relax fixes
  it. Not a density slot. Doc: `wave2\FTMO_GATE_13209_diagnosis_2026-07-21.md`.
- **QM5_20023 (Savor–Wilson macro-announcement day) → FIXABLE_REBUILD.** Root cause of ZERO_TRADES:
  the `strategy_event_whitelist="NFP|CPI|PPI|FOMC"` setfile value is **pipe-truncated by MT5** to
  `"NFP` → the locked-value mismatch permanently blocks all trades. Second, doctrine-critical: the
  announcement calendar misdates BLS releases by a day and splits FOMC across two dates → a
  setfile-only unblock would trade look-ahead/duplicated days. Rebuild in progress (Codex, in a
  worktree): change the whitelist delimiter `|`→`,` + a strategy-scoped calendar correction; requeue
  held for Claude review. Doc: `wave2\FTMO_GATE_20023_diagnosis_2026-07-21.md`.

## 5. Open threads / next actions
- [ ] Adjudicate the 20023 rebuild (Codex worktree) → requeue Q02 once verified.
- [ ] Integrate the 3 Reddit ideas: correlation-cluster caps, MAE/MFE exits (→ Exit-Surgery Tier B),
      DSR promotion gate; MC shock-tail + outlier-strip. Gate-affecting changes → OWNER-DL.
- [ ] Review the Codex "fresh ideas" output + the MQL5 mining shortlist.
- [ ] Browser-mine Forex Factory + BabyPips (Cloudflare — Chrome only) when prioritised.
- Note: agy currently writes its report to its internal brain dir; future agy dispatches should be
  told to write the deliverable under `D:\QM\reports\state\…`.
