# Claude review: QM5_12955 Gemini build

- Review task: `4e370f87-6e6d-4b8b-ac0f-31413f6b8092`
- Gemini source task: `4f5b3b2b-7c8d-4da1-ad62-7577640ddce5`
- Source artifact: `artifacts/builds/4f5b3b2b-7c8d-4da1-ad62-7577640ddce5.json`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12955_mql5-aroon-cross-card.md`
- MQ5 SHA-256: `1ea60257401d33226ee078e3777d042d11bcb6c9a0207f673571ed0ef3aa177f`
- EX5 SHA-256: `87e6c2da26127b5fb8bdfadda67204f1cb03aa324ae63b2cb61bf82357d21a8e`
- Verdict: **CHANGES_REQUIRED — remain in REVIEW; Codex confirmation still required per Gemini-code policy**

The router assigned this `review_ea` task to Claude with reason
`codex_review_required_for_gemini_code`. Per CLAUDE.md, Codex review of
Gemini-authored code is mandatory before acceptance, so this task stays in
`REVIEW` regardless of this verdict — it does not move to APPROVED/PIPELINE.

## Findings

### 1. Block: `GER40.DWX` is not a canonical DWX symbol in the matrix

`framework/registry/dwx_symbol_matrix.csv` has no `GER40.DWX` row; the DAX
instrument's canonical DWX symbol is `GDAXI.DWX` (confirmed present, and
used correctly by the sibling build QM5_1345 today). The card's target
list (`EURUSD.DWX, GBPUSD.DWX, GER40.DWX`) and the build's magic-registry
row (`framework/registry/magic_numbers.csv` line for ea_id 12955, slot 2)
both carry the non-canonical name. Six pre-existing rows for other EAs
already use `GER40.DWX`, so this is a latent registry-naming defect, not
one this build introduced — but per the review checklist an unmatched
symbol is a block finding regardless of precedent. Needs either a matrix
entry for `GER40.DWX` as an accepted alias, or the build/card should be
corrected to `GDAXI.DWX` and the magic row/setfile regenerated.

### 2. Block: no smoke-test evidence in the build result

`artifacts/builds/4f5b3b2b-7c8d-4da1-ad62-7577640ddce5.json` has none of
`smoke_result`, `smoke_report_path`, `blocked_reason`, `magic_base`, or
`symbols_registered` — fields the `build_result.json` schema
(`tools/strategy_farm/prompts/SCHEMAS.md`) requires. There is no
`deferred_p2_smoke` marker with capacity evidence either. Per
`claude_review_ea.md` §6, approval requires `smoke_result: "passed"`
(≥1 trade in the smoke window); that cannot be confirmed here. Evidence
over claims: a clean compile is not proof the entry logic ever fires.

## Independent verification

- Fresh read of `QM5_12955_mql5-aroon-cross-card.mq5`: entry (Aroon(25)
  up/down cross), exit (opposite cross), SL 200 pts / TP 600 pts, and
  symbol universe all match the approved card body exactly (§Mechanik).
  §1 Mechanical Match: PASS.
- HR14 (no ML): no adaptive/learned parameters, no NN/ONNX calls,
  `MathRand` not used. PASS.
- HR4 (risk model): `RISK_FIXED`/`RISK_PERCENT` inputs present; all three
  generated setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`. PASS.
- HR5 (magic): `qm_ea_id * 10000 + qm_magic_slot_offset` wired through
  `QM_FrameworkMagic()`; the 3 `magic_numbers.csv` rows for ea_id 12955
  (slots 0/1/2 → 129550000/1/2) are collision-free, and
  `QM_MagicResolver.mqh` (regenerated 2026-08-22 11:19, same session)
  carries exactly 3 matching rows. PASS.
- Framework architecture: `OnInit`/`OnTick`/`OnDeinit`/`OnTimer`/
  `OnTradeTransaction`/`OnTester` all present; no-trade filter, entry,
  manage, exit sections all present. PASS.
- Framework corset: only `iHighest`/`iLowest` used for the Aroon
  high/low-recency search (no `QM_Aroon` reader exists in
  `QM_Indicators.mqh`, so this is the sanctioned bespoke path — not one
  of the forbidden raw `iATR/iMA/iRSI/iMACD/iADX/iBands` calls). No raw
  `OrderSend`, no hardcoded magic, no `IndicatorRelease` in EA code. PASS.
- Perf **warn**: `Strategy_ExitSignal()` is called every tick (line 250,
  before the `QM_IsNewBar()` gate at line 262) and recomputes Aroon(1) via
  `iHighest`/`iLowest` over 25 bars each time a position is open, even
  though the shift-1 value is constant within the forming bar. Not a
  block (native searches, not a manual per-tick loop), but should be
  cached/gated by `QM_IsNewBar()` before P3 multi-period sweeps.
- News-gate ordering **advisory**: the news-blackout check runs before
  `Strategy_ManageOpenPosition`/`Strategy_ExitSignal`, ahead of the
  canonical kill-switch → Friday-close → NoTradeFilter → Manage → Exit →
  news → IsNewBar → Entry order. Every entry always sets a non-zero
  server-side SL (`if (sl <= 0.0) return false;`), so per the
  ONTICK-ORDER rule this is an advisory, not a FAIL — stop enforcement
  is not suspended during news windows.
- Naming/dir conventions: `framework/EAs/QM5_12955_mql5-aroon-cross-card/`
  with correct `QM5_` prefix; `.mq5`/`.ex5` basenames match; setfiles
  exist in `sets/` for all 3 `symbols_registered` (`EURUSD.DWX`,
  `GBPUSD.DWX`, `GER40.DWX`). PASS except the symbol-matrix gap in
  Finding 1.
- `build_check_passed: true`, `compile_succeeded: true`, `compile_errors:
  0`, `compile_warnings: 0` per the build artifact. No independent
  recompile was run in this session (read-only review; no source, setfile,
  registry, resolver, or work-item mutation performed).

No `.mq5`, registry, resolver, work item, terminal, AutoTrading, or
pipeline state was changed by this review.
