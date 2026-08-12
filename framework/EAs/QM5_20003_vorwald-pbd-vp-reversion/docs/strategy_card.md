---
ea_id: 20003
slug: vorwald-pbd-vp-reversion
strategy_id: NILL-VORWALD-PBD-2026
status: intake
owner: claude
created_at: 2026-07-16
target_symbols: [EURUSD.DWX, GBPUSD.DWX]
primary_target_symbols: [EURUSD.DWX]
timeframes: [H1, H4, D1]
period: H1
expected_trades_per_year_per_symbol: 200
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/range-reversal]]"
  - "[[concepts/volume-profile-value-area]]"
  - "[[concepts/impulse-range-reversion]]"
source_citations:
  - type: research
    citation: "Deep-dive reverse-engineering of Patrick Nill (WCTC/World Cup Trading Championships Robbins-audited, +72% to +277%/yr, overwhelmingly on the Forex-division CFD account) and his named method-creator/mentor Tom Vorwald (7 primary YouTube transcripts, Vorwald credits 'my student Patrick Nill' by name). Method = 'PBD' (P=impulse up, B=impulse down, D=balance/range) on classical Volume/Market-Profile concepts. Nill states directly: 'you can't really use orderflow in the Forex market so we don't use it there' -> the audited FX edge is price/tick-volume only, buildable on .DWX."
    location: "D:\\QM\\reports\\research\\nill_valentini_scalper_survey_2026-07-16.md (DEEP DIVE: Patrick Nill); transcripts D:\\QM\\reports\\research\\nill_transcripts\\"
    quality_tier: B
    role: primary
---

# Vorwald/Nill PBD Volume-Profile Range-Reversion (QM5_20003)

QM hypothesis inspired by the reverse-engineered footprint of Patrick Nill's (Robbins-audited)
Forex swing method — NOT a claim of his exact rules (calibration is genuinely paywalled).

## Edge hypothesis (reconstructed skeleton, MEDIUM confidence)
**Impulse-Range-Reversion at Volume-Profile Confluence:** detect an impulse leg (P up / B down),
then a balance/range phase (D). A **liquidity sweep / false break of a range extreme that
coincides with a tick-volume Value-Area edge / POC** triggers a **reversal** back into value;
stop beyond the swept extreme; **target = retracement to the impulse origin** (min ~1:2 R:R).
Swing-frequency (hold ~4h–3 days), low win-rate/positive-expectancy profile (WCTC footprint:
win rate 30–65%, 10–20-trade losing streaks normal, ~3–5 trades/week).

## Why buildable on .DWX (unlike Valentini)
Nill's own words: order-flow/footprint is **explicitly not used** on his FX-CFD edge. Value Area
is derived from **tick-volume** — which is exactly the data class FX offers anyone (no centralized
volume), so our `.DWX` tick-volume is the *same* proxy he uses, not a degraded one. No footprint/
CVD/DOM dependency → fully codeable from OHLCV/tick-volume.

## Overlap verdict (checked 2026-07-16)
Distinct variant, NOT a duplicate of QM5_13033_novo-crt-h4-sweep-reversal: shares the
sweep-reversal primitive but differs in universe (FX vs NDX/XAU), holding period (swing vs
H4-anchor intraday), and adds a real Volume-Profile-Value-Area + impulse-range (P/B/D) +
impulse-origin-target confluence layer that 13033 lacks. **★Q09 correlation vs 13033 (and any
FX sweep-reversal sleeves) is the binding admission check** — the shared primitive means it must
empirically decorrelate to add book value.

## Honesty / caveats
- MEDIUM confidence: the P/B/D + sweep-reversal skeleton is corroborated across 7 primary
  recordings (trader + teacher, stated independently). The **exact numeric calibration** (impulse
  threshold, range definition, value-area lookback) is paywalled and NOT guessed — it must be
  found as the single tuned dimension via fixed-param walk-forward, guarded against PBO/DSR.
- Nill's performance claims: treat as marketing; the WCTC standings are the only audited evidence.
  The backtest, not the source, must produce the expectancy.
- Per-idea risk ≤1% (book rule); RISK_FIXED backtest / RISK_PERCENT live; no ML; MT5-native only.

## Pipeline
Phase 1: mechanize the skeleton on EURUSD H1 (HTF context H4/D1 for impulse+range), then GBPUSD.
Volume-Profile value-area from tick-volume over a rolling/session window. Gates Q02–Q10 decide;
Q09 must clear the correlation check vs 13033.
