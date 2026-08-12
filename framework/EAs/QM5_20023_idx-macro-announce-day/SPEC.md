# QM5_20023_idx-macro-announce-day — Strategy Spec

**EA ID:** QM5_20023
**Slug:** `idx-macro-announce-day`
**Source:** `SAVOR-WILSON-ANNDAY-2013`
**Author of this spec:** Codex
**Last revised:** 2026-07-21 (Wave-2 calendar rebuild)

---

## 1. Strategy Logic

The EA buys after the first H1 bar completes on a broker day containing a
scheduled USD Non-Farm Employment Change, Nonfarm Payrolls, CPI m/m, PPI m/m,
FOMC Statement, or Federal Funds Rate release. It places a frozen stop 2.75
times the completed D1 ATR(20) below entry and never sets a take-profit. It
closes in the final H1 bar of that broker day, with a next-day stale-position
guard, and permits only one attempted package per event day and symbol.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_whitelist` | `NFP,CPI,PPI,FOMC` | locked | Fixed ex-ante event families; comma serialization preserves the complete value in MT5 tester presets. |
| `strategy_atr_period` | `20` | locked | Completed D1 ATR period used for the initial hard stop. |
| `strategy_atr_sl_mult` | `2.75` | locked | Multiplier applied to the completed D1 ATR value. |
| `strategy_entry_bar` | `first_h1_of_event_day` | locked | Enter only after the event day's first H1 bar has completed. |
| `strategy_exit_bar` | `last_h1_of_event_day` | locked | Flatten in broker hour 23, with a next-day stale guard. |
| `strategy_max_spread_points` | `2500` | locked | Maximum genuinely positive spread in symbol points; zero modeled spread is valid. |

Framework-level inputs are documented in
`framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — direct S&P 500 proxy for the paper's US equity-market return.
- `NDX.DWX` — liquid Nasdaq 100 US large-cap index port named in the approved card.
- `WS30.DWX` — liquid Dow 30 US large-cap index port named in the approved card.

**Explicitly NOT for:**

- Non-index `.DWX` instruments — the approved hypothesis and R3 portability decision are limited to the three registered US equity indices.
- Phantom S&P aliases such as `SPX500.DWX`, `SPY.DWX`, or `ES.DWX` — they are not canonical matrix symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Completed `D1` ATR(20), shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the canonical skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 40 scheduled US announcement days |
| Expected trade frequency | About 12 NFP, 12 CPI, 12 PPI, and 8 FOMC decisions annually, with same-day overlaps deduplicated |
| Typical hold time | Remainder of one broker day, normally about 22 hours; Friday positions close earlier under the framework rule |
| Expected drawdown profile | Medium risk; card expectation is approximately 20% drawdown |
| Regime preference | News-driven scheduled macro-risk-premium days |
| Win rate target (qualitative) | Not specified by the card; expected PF is 1.05, so the edge is deliberately modest |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `SAVOR-WILSON-ANNDAY-2013`
**Source type:** academic paper
**Pointer:** Savor and Wilson (2013), Journal of Financial and Quantitative
Analysis 48(2), 343–375; SSRN
`https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1312091` and RePEc
`https://ideas.repec.org/a/cup/jfinqa/v48y2013i02p343-375_00.html`
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_20023_idx-macro-announce-day.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-21 | Initial build from card | `d5037fee-7ed7-4327-a314-1919b5a1b017` |
| v2 | 2026-07-21 | Wave-2 diagnosis rebuild | Pipe-free locked whitelist plus strategy-scoped, source-proven announcement calendar. |
