# QM5_12816_harmonic-cypher - Strategy Spec

**EA ID:** QM5_12816
**Slug:** harmonic-cypher
**Source:** forexalgotrader-harmonic-cypher-part15-2026
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA detects a confirmed five-swing Cypher pattern on closed bars only. A bullish pattern requires low-high-low-high-low swings with B retracing 0.382-0.618 of XA, C extending 1.272-1.414 of XA, and D retracing 0.786 of XC within tolerance; the bearish pattern is the inverse. It places a buy limit or sell limit at D, uses a stop just beyond X, sets broker TP at the 0.618 retrace of CD, then partially closes at the 0.382 retrace of CD and moves the remainder to break-even.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_swing_depth | 5 | 2-20 | Bars on each side required to confirm a swing high or swing low. |
| strategy_scan_bars | 260 | 60-500 | Closed-bar window searched for the latest alternating swing sequence. |
| strategy_d_tolerance | 0.02 | 0.01-0.10 | Absolute tolerance around the fixed 0.786 XC retrace at point D. |
| strategy_pending_expiry_bars | 6 | 1-48 | Number of chart bars before an unfilled D-limit order expires. |
| strategy_partial_close_pct | 50.0 | 0-90 | Percent of open volume to close at TP1 before moving the runner to break-even. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Card names XAUUSD/gold as a low-commission harmonic target.
- SP500.DWX - Canonical S&P 500 custom symbol for the card's US500/SP500 target.
- NDX.DWX - Canonical Nasdaq 100 symbol for the card's NDX/US100 target.
- GDAXI.DWX - Canonical DAX symbol for the card's GER40 target.

**Explicitly NOT for:**
- FX majors - The card explicitly defers FX because the pattern is rare and commission impact is higher.
- SPX500.DWX, SPY.DWX, ES.DWX - Not available canonical DWX symbols for the S&P 500 target.
- Sector ETFs - Not named by the card and not part of the approved low-commission basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 variant generated as a separate setfile; no cross-timeframe reads |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Swing hold; exits are TP1/TP2, SL, expiry, or framework Friday close |
| Expected drawdown profile | About 10% expected drawdown from card frontmatter |
| Regime preference | Harmonic exhaustion reversal after extended XA/XC geometry |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** forexalgotrader-harmonic-cypher-part15-2026
**Source type:** video/channel analysis extracted by AI research tooling
**Pointer:** docs/research/FOREX_ALGO_TRADER_CHANNEL_ANALYSIS_2026-06-29.md, Part 15
**R1-R4 verdict (Q00):** all PASS / see artifacts/cards_approved/QM5_12816_harmonic-cypher.md

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-30 | Initial build from card | 3789bc6a-f29a-4b84-8916-911929dc5eb2 |
