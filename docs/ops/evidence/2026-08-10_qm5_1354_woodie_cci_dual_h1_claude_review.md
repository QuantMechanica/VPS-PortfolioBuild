# QM5_1354 woodie-cci-dual-h1 — Claude code review

- **Task:** review_ea `0c9d9f82-8b4a-408a-9b82-a9d89e9ab106` (source_agent: gemini, source_execution_backend: agy)
- **Card:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1354_woodie-cci-dual-h1.md`
- **Reviewer:** Claude, 2026-08-10
- **Verdict:** PASS, no blocking defects. Left in REVIEW per Hard Rule "Codex review is mandatory before acceptance" — not self-approved to APPROVED/PIPELINE.

## Mechanical verification (independently re-run, not trusted from source_verdict)

- `compile_ea.py --ea-id 1354 --force`: COMPILED, 0 errors / 0 warnings.
- `validate_build_guardrails.py`: PASS, 0 findings (9 files checked).
- `build_check.ps1 -EALabel QM5_1354_woodie-cci-dual-h1 -SkipCompile`: PASS, 0 failures / 0 warnings.
- 8 backtest setfiles present for all card `target_symbols` (EURUSD/GBPUSD/USDJPY/AUDUSD/
  XAUUSD/NDX/WS30/GDAXI.DWX), RISK_FIXED=1000 / RISK_PERCENT=0 confirmed in setfile content.

## Card-fidelity checks (bar-index arithmetic verified explicitly)

Variable-to-bar mapping (EA uses `g_trend_cci[1..6]`/`g_turbo_cci[1..3]`, index = shift,
so index 1 = bar `t` (last closed), index 2 = `t-1`, index 3 = `t-2`):

- **Trend gate**: `bull_trend`/`bear_trend` requires `g_trend_cci[1..6]` all same-signed
  → matches card's "TrendCCI > 0 (or < 0) for at least 6 closed H1 bars."
- **BUY ZLR pattern**: `g_turbo_cci[3] > 100` (Turbo[t-2] overbought) AND
  `g_turbo_cci[2] <= 0` (Turbo[t-1] pulled to/through zero) AND `g_turbo_cci[1] > 0`
  (Turbo[t] > 0) AND `g_turbo_cci[1] > g_turbo_cci[2]` (rejecting back up) — matches
  card's ZLR definition term-for-term (SELL is the exact mirror, verified).
- **Exits**: TrendCCI-flip primary exit (`g_trend_cci[1] < 0` for an open BUY) matches;
  TurboCCI extreme partial-close at ±250 matches; TP at 2.5x ATR(14) set on the entry
  request matches; 48-bar time-stop matches.
- **Stop loss**: `entry - 1.8 * ATR(14)` (BUY) / mirror (SELL) matches card's
  `entry - 1.8 x ATR(14, H1)` exactly (no bar-anchor ambiguity here, unlike the sibling
  QM5_1355 review — this card's SL is purely ATR-distance from entry, not a bar low).
- **One-ZLR-per-trend-leg**: `g_buy_suppressed`/`g_sell_suppressed` set true on entry,
  reset when `TrendCCI` flips sign — matches card's "suppress new BUY ZLR entries until
  TrendCCI flips below zero."
- **Session window** 06:00-22:00 broker-time, **1-pos-per-magic**, **news filter** via
  `qm_news_temporal`/`qm_news_compliance` framework inputs (PRE30_POST30 / DXZ, matching
  card's "30-min skip before/after high-impact news") all match.
- **Spread guard**: EMA(alpha=0.095, i.e. ~20-bar-equivalent smoothing) used as a proxy
  for the card's literal "20-bar median spread." Not a bug — EMA vs median is a
  reasonable, common engineering substitution and is not a hard-rule violation — but
  noting the deviation for the record since it changes tail behavior slightly (EMA is
  less resistant to a single spread spike than a true median).

No defects found. No off-by-one or unused-input issues located (unlike the QM5_1355
sibling reviewed alongside this one, which had two real defects — see
`2026-08-10_qm5_1355_williams_vix_fix_fx_h4_claude_review.md`).
