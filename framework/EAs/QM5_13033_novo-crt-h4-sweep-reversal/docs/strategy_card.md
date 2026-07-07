---
ea_id: QM5_13033
slug: novo-crt-h4-sweep-reversal
type: strategy
strategy_id: YT-NOVO-LEGACY-2026-07_CRT-H4-SWEEP
source_id: YT-NOVO-LEGACY-2026-07
source_citation: "Novo Legacy (2026), the trading industry is broken... so I'm leaking my $8.5k course, YouTube video fNFTpKmSQB8; mechanization dossier with 4561 transcript rows and per-rule timestamps: docs/ops/evidence/3b1fe1ab_novo_legacy_mechanization_dossier_2026-07-07.md."
source_citations:
  - type: video
    citation: "Novo Legacy. the trading industry is broken... so I'm leaking my $8.5k course. YouTube, 2026. Video ID fNFTpKmSQB8 (author publishing his own course material)."
    location: "https://www.youtube.com/watch?v=fNFTpKmSQB8"
    quality_tier: C
    role: primary
  - type: internal_research
    citation: "QM mechanization dossier, ticket 3b1fe1ab (codex lane): full public-caption transcript (4561 rows, proxy-fetched with attempt evidence), CIT+CRT rule sets with per-rule timestamps, formalization flags, discretionary discard list. Cross-corroborated by independent gemini-lane extraction (ticket fe1704fc round 2, Strategy 3)."
    location: "docs/ops/evidence/3b1fe1ab_novo_legacy_mechanization_dossier_2026-07-07.md"
    quality_tier: B
    role: primary_evidence
sources:
  - "[[sources/YT-NOVO-LEGACY-2026-07]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/range-reversal]]"
  - "[[concepts/session-anchored-range]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [range-sweep-reversal, h4-anchor-candle, session-window, m5-entry, single-position, time-flatten, ftmo-sprint-mandate]
target_symbols: [NDX.DWX, XAUUSD.DWX]
primary_target_symbols: [NDX.DWX]
markets: [NDX.DWX, XAUUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13033_CRT_H4_SWEEP_M5
period: M5
timeframes: [M5, H4]
expected_trade_frequency: "One anchor candle per day, range-day filter plus sweep-in-window plus trigger requirement gate hard; estimate roughly 1-2 entries/week/symbol, approximately 60 trades/year/symbol; zero-trade weeks in strong trend regimes are expected."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.15
expected_dd_pct: 12.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual, news_blackout_firm_windows, broker_time_convention]
g0_approval_reasoning: "OWNER FTMO-sprint mandate (decisions/2026-07-06_ftmo_scalping_grid_mandate.md) G0 approval 2026-07-07 (Claude): R1 author's own published course video with dense taught examples (performance claims none beyond anecdote; pipeline judges); R2 rule set mechanical after the two codification decisions documented in-card (CISD trigger, breaker-retest dropped) — flagged as required reviewer decisions by the dossier and decided here; R3 NDX.DWX/XAUUSD.DWX M5+H4 real-tick history available; R4 no ML, no grid, no martingale — single position, hard stop, time flatten."
---

# Novo CRT H4 Range-Sweep Reversal (M5 entry, NDX + XAU)

## Source

- Primary: Novo Legacy, "the trading industry is broken... so I'm leaking my
  $8.5k course", YouTube fNFTpKmSQB8 (author publishing his own course —
  provenance clean).
- Evidence: mechanization dossier
  `docs/ops/evidence/3b1fe1ab_novo_legacy_mechanization_dossier_2026-07-07.md`
  (4561 transcript rows, per-rule timestamps, formalization flags), transcript
  JSON + proxy-attempt evidence under
  `D:/QM/strategy_farm/artifacts/research/`. Independent second extraction
  (gemini lane, ticket fe1704fc) corroborates anchor candle, sweep window,
  sweep definition, bias and targets.
- The dossier ranks CRT as the stronger first card: anchor range, sweep
  window, bias, stop and base target are objective; only the entry trigger
  needed codification (done below).

## Hypothesis

A completed 4H candle after indecisive conditions defines an objective range.
A fast excursion beyond that range during the New York morning window that
immediately closes back inside is a failed breakout / liquidity sweep; price
then disproportionately traverses back toward the opposing side of the range
[00:57:41-01:00:22, 01:33:20-01:34:38]. Index CFDs and gold are the taught
and mandate-preferred venue.

## Market universe and timeframe

- Symbols: NDX.DWX (primary; author's main instrument class), XAUUSD.DWX.
  Per-symbol EA instances.
- Frequency estimate: 60 trades per year per symbol (1-2 per week; the
  range-day filter and single-setup-per-day rule bound it).
- Anchor timeframe: H4. Entry timeframe: M5 (literal tokens: H4, M5; author's
  taught default is 4H context to 5M entry [00:31:11-00:31:19]).
- Broker-time mapping (hard-bounded convention): the author's 5:00 a.m. ET
  anchor candle (closes 9:00 ET) is EXACTLY the DWX H4 candle opening at
  12:00 broker time (NY-close GMT+2/+3 => broker = ET + 7h year-round).
  Sweep window 9:00-11:30 ET = 16:00-18:30 broker time. No DST drift by
  construction; document in EA header.

## Entry

All decisions on closed bars only.

1. Anchor: the H4 candle opening 12:00 broker time. Wait for its close at
   16:00 broker (no decision before the anchor closes [01:01:50-01:03:10]).
   Record anchor_high, anchor_low, anchor_mid = (high+low)/2.
2. Range-day filter [01:01:10-01:01:28, 01:55:50-01:56:22], codified:
   (a) anchor candle body < body_max_frac (default 0.5) of its high-low
   range (more wick than body), AND (b) mean body/range over the three H4
   candles before the anchor < prior_body_max_frac (default 0.5). Both are
   inputs; the filter marks the day CRT-eligible.
3. Sweep [01:33:16-01:33:35]: within 16:00-18:30 broker time, a closed M5
   bar whose extreme trades beyond the anchor range but whose CLOSE is back
   inside it. High-side sweep => bearish bias toward anchor_low; low-side
   sweep => bullish bias toward anchor_high [01:33:42-01:34:38]. First
   qualifying sweep per day wins; one setup per day per symbol.
4. Entry trigger — CISD codification (reviewer decision required by the
   dossier [01:19:15-01:19:55], decided here): for a bearish setup, define
   the sweep run as the maximal consecutive sequence of up-closing M5 bars
   ending at the sweep extreme bar; trigger = first closed M5 bar with close
   below the minimum OPEN of that run. Degenerate run (single bar) fallback:
   close below the sweep bar's low. Bullish symmetric. Enter AT MARKET on
   trigger-bar close. The author's breaker-block retest refinement is
   DROPPED (deliberate deviation, documented): it lacks a formal definition
   in the source and would add a visual-discretion axis.
5. Trigger validity window: the trigger must occur within trigger_window_min
   (default 120) minutes after the sweep bar, else the setup is abandoned.
6. Single exposure: one position max; no adds, no re-entry after a completed
   trade for the day (one trade per day per symbol).

## Exit

- Stop loss [01:57:32-01:57:43]: beyond the sweep-side extreme —
  short: max(sweep extreme, anchor_high) + 0.1*ATR(14, M5) buffer;
  long: min(sweep extreme, anchor_low) - 0.1*ATR(14, M5).
- Take profit (primary) [00:59:49-01:00:22]: the opposing side of the anchor
  range (short: anchor_low; long: anchor_high). Input tp_mode allows the
  author's conservative 50%-of-range alternative (anchor_mid)
  [01:57:55-01:58:25]; default full-range.
- Time flatten (codified from live-management commentary
  [02:00:50-02:01:21]): flatten any open position at 20:00 broker time
  (13:00 ET) — the setup is a morning-resolution trade; holding past the NY
  lunch is outside the taught pattern. Deterministic session exit includes
  pending/positions both.
- Framework Friday close and news handling on top (Manage/Exit before news
  gate per the 2026-07-02 audit rule).
- Fibonacci extension targets (1.272/1.7/2.145 [01:28:40-01:31:10]) are NOT
  used in v1 — the anchor for "recent high/low" is underspecified; candidate
  for a v2 exit-surgery pass, not a launch feature.

## Risk and sizing

- RISK_FIXED for backtests, RISK_PERCENT for live (source is sizing-silent;
  dossier prescribes QM defaults).
- Single position with a hard stop => worst case per symbol = per-trade risk
  percent; live risk_percent MUST be <= 1.0 per the OWNER mandate cap
  (decisions/2026-07-06_ftmo_scalping_grid_mandate.md).
- Stop distance is structural (range extreme + buffer), typically well under
  one anchor range; RR to the opposing side is usually >= 1:1 by geometry.

## Filters

- News: mandatory blackout via the framework news filter (the author himself
  forbids entries before 8:30 ET red-folder news [01:26:01-01:26:17]); FTMO
  firm-window compliance axis active on the live track.
- Spread gate: entries only while spread <= max_spread_points (per-symbol
  input, set from median DWX spread * 2 at build).
- No-trade day: if the range-day filter fails, or no sweep occurs in the
  window, or the trigger window lapses — no trade that day (expected most
  days).

## Falsification

- Q02 gross full-history (2017-2025) PF < 1.20 at the card floor kills the
  family; no rescue beyond stated defaults plus the standard Q03 trial grid.
- If the edge exists only with the conservative 50% target but not the
  full-range target (or vice versa), keep the surviving mode only; if
  neither, dead.
- If Q04 walk-forward shows the NY-window sweep edge is entirely
  pre-2020 (regime artifact), retire rather than re-window.
- Symmetric failure honesty: no long-only/short-only rescue unless the
  directional split is structurally motivated AND passes Q04 on its own.

## Q08-Q11 risks

- 8.4 regime dependence: range-reversal logic starves in persistent trend
  regimes (2021, 2024 melt-ups on NDX) — expect lumpy annual distribution;
  the range-day filter is the mitigation, and DL-076 pooled-OOS may apply at
  the frequency boundary.
- DL-072 cost cushion: M5 structural stops on NDX/XAU must clear 2x
  worst-case commission on gross expectancy — likely the honest killer if
  the edge is thin.
- Q09: NY-morning index range-reversal is conceptually orthogonal to the D1
  swing book and to 13031's BB-stretch MR (different anchor, different
  session, different mechanism); XAU instance overlaps 13031/XAU in symbol —
  admission dedups if both survive.
- Fill sensitivity: market entry on M5 close is less fill-model sensitive
  than stop/limit mechanics; Model 4 real-tick standard applies.

## Implementation notes

- V5 framework build; closed-bar M5 evaluation; H4 anchor read via M5-derived
  H4 series or iHigh/iLow on PERIOD_H4 with broker-time alignment checked at
  init (candle open times 00/04/08/12/16/20 broker — abort with clear log if
  the H4 grid is offset). Set QM_EntryRequest.symbol_slot explicitly.
- State machine per day: WAIT_ANCHOR -> RANGE_CHECK -> WAIT_SWEEP (16:00-
  18:30) -> WAIT_TRIGGER (trigger_window) -> IN_TRADE -> DONE; reset at the
  next 12:00 broker anchor.
- Inputs (build defaults): body_max_frac=0.5, prior_body_max_frac=0.5,
  sweep_window_start=16, sweep_window_end_min=18*60+30, trigger_window_min=120,
  sl_buffer_atr=0.1 (ATR 14 on M5), tp_mode=full_range, flatten_hour=20,
  max_spread_points per symbol.
- Deliberate deviations from source (documented): breaker-retest dropped,
  CISD codified as run-open break with sweep-low fallback, hard 20:00 time
  flatten, framework sizing/news/Friday handling. Everything else follows
  the dossier's timestamped rules; CIT (the companion continuation system)
  is deliberately NOT in this card — separate wave-2 candidate pending
  13031/13032 Q02 outcomes.
