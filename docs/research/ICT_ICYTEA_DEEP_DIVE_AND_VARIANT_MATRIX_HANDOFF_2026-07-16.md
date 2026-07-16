# ICT icy-tea — Deep Root-Cause + Full Variant×Symbol Matrix (Codex handoff)

**Owner:** OWNER mandate 2026-07-16 — "ICT is not dead, only insufficiently implemented."
**Lane:** Codex, best model (gpt-5.5), implementation-aware. Deep + thorough.
**EA:** `framework/EAs/QM5_20002_ict-icytea-core/` (faithful two-phase engine, compiled, committed).
**Spec:** `MQL5_Strategie_Spezifikation_some_icy_tea.docx` (Downloads) / extracted `D:\QM\reports\ict_intake\spec.txt`.
**Reference truth:** `Trades_some_icy_tea.xlsx` (770 annotated winning trades — the ground truth to reproduce).

## What is already established (do NOT re-litigate)
The core model (sweep→MSS+displacement→FVG/OB entry, premium/discount, SL behind sweep,
TP at opposite liquidity) was CRIPPLED by an implementation bug (FVG forced onto the MSS bar →
4 trades/yr). It was faithfully rewritten to the two-phase model (impulse-leg FVG scan + retrace
entry). Frequency fixed (4 → 17–72/yr). Clean 4-year evidence on EURUSD M1 (gross, .DWX = $0 comm):

| Year | Trades | Gross PF | Net |
|---|---|---|---|
| 2022 | 72 | 0.96 | −$1,169 |
| 2023 | 28 | 0.59 | −$6,614 |
| 2024 | 17 | **2.58** | **+$6,026** |
| 2025 | 14 | 0.44 | −$5,042 |

Pooled gross PF **0.889**, 1/4 years positive. A Phase-2 HTF-bias filter (H1 BOS, `UseHTFBias`)
made it WORSE (pooled 0.778) — it concentrated outcomes (2024→PF 5.14) but did not predict.
Evidence: `D:\QM\reports\smoke\ict_rescue_v2*` (no-bias) and `ict_htf_*` (HTF-bias), years 2022–2025.

## Task 1 — Deep root-cause: why is 2024 grandiose and the rest disastrous?
This is the crux. 2024 stood alone at PF 2.58 (and PF 5.14 with the HTF-bias) while 2022/2023/2025
lose. Find the *filterable* reason, using **trade-level** data (parse each year's `report.htm` deal
table under the report dirs above; the reference xlsx gives the author's winning-trade fingerprint).
Hypotheses to test rigorously (rank + falsify):
1. **Regime**: 2024 EURUSD trend/volatility/range structure vs the losing years (ATR regime, daily
   trend persistence, session-range expansion). Is the edge conditional on a measurable regime?
2. **Directionality**: 2024 winners were ~15/17 shorts. Is the edge one-sided / dependent on the
   yearly directional drift? (The losing years had weak longs — 2023 longs 11tr @ 18% win.)
3. **Setup concentration**: does 2024 concentrate a specific PD-array (Breaker/Unicorn/iFVG/OB vs
   plain FVG) or session (London vs NY) that the losing years lack?
4. **Liquidity-target quality**: are 2024's TPs hitting cleaner external pools (PDH/PDL, session H/L)
   vs the losing years chasing weak EQH/EQL?
5. **News/time**: overlap of winners with specific killzone micro-windows or post-news reversals.
Deliverable: a verdict — is there a *mechanizable* condition that isolates the 2024-type edge across
all years (→ implement it as a filter and re-test), or is 2024 a genuine regime outlier (→ the core is
regime-only, size accordingly or shelve)? Back the verdict with trade-level evidence, not narrative.

## Task 2 — Implement + test the Ch5 setup variants on ALL named symbols
The spec's Ch5 variants are currently **no-op stubs** in the EA (`ICT_Setup_*_Entry` return false).
Implement them faithfully (each shares the Ch3 core; they differ in trigger/time-window/filter) and
test each on the full symbol universe from the spec's 770-trade distribution:

- **Variants**: Judas Swing (5.1), Turtle Soup / sweep-in-HTF-array (5.2), Unicorn = Breaker∩FVG (5.3),
  Silver Bullet time-window (5.4), SMT-divergence filter (5.5), 3 Drives (5.6), Market-Maker model (5.7),
  TGIF Friday (5.8), Index-Macros (5.9).
- **Symbols** (spec §2.1 frequency): EURUSD (493), GBPUSD (156), NAS100→**NDX.DWX** (35), XAUUSD (26),
  USDCAD (21), ES/S&P→**NDX/WS30.DWX** port (~15), AUDUSD (5). **TFs**: M1 primary, also M5/M3, M15 context.
- Route via factory Q02 (preferred — managed, `.DWX` symbols) or the ad-hoc harness (`compile_one` +
  `run_smoke` on a parked/free terminal; 1–2 concurrent max — parked T8/9/10 tick-starve on 3+).
- **Note**: Silver Bullet (pure time-window) and Judas (session-timed) are the most *mechanically distinct*
  from the core; prioritize those — they may carry an edge the plain core lacks.

## Guardrails
- `RISK_FIXED` for backtests; `.DWX` symbols only (never raw broker symbols).
- Compile ONLY via `framework/scripts/compile_one.ps1` (never raw metaeditor — stale-resolver trap).
- Real-tick Model 4. Cost-correct any survivor (FX comm ~$45/trade, index ~$4.4) — .DWX runs are gross.
- Report every variant×symbol result (trades, PF, gross+net) so nothing is silently dropped.

## Success = one of
(a) a mechanizable filter that lifts the pooled core edge to PF≥1.20 net across years, OR
(b) a specific variant×symbol combo that clears Q02+Q04 on its own merits → into the pipeline, OR
(c) a rigorous, evidence-backed "ICT-family has no mechanical edge on the DWX universe" close.
