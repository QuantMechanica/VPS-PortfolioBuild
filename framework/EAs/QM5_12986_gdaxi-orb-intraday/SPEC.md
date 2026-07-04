# QM5_12986_gdaxi-orb-intraday — Strategy Spec

**EA ID:** QM5_12986
**Slug:** `gdaxi-orb-intraday`
**Source:** `CEO-PROPTRACK-SLATE-2026-07-03` (see `strategy-seeds/sources/CEO-PROPTRACK-SLATE-2026-07-03/`)
**Author of this spec:** Development
**Last revised:** 2026-07-04

---

## 1. Strategy Logic

At the start of each Xetra cash session (09:00 CET/CEST, mapped to DXZ broker time via a DST-aware computation), the EA records the high and low of the first 60 minutes of trading (4 M15 bars). This defines the Opening Range. After checking that the range is neither degenerate (too narrow: < 0.15 × D1 ATR) nor exhausted (too wide: > 1.0 × D1 ATR), the EA waits for the first M15 close beyond the range boundaries: a close above the range high triggers a BUY, a close below the range low triggers a SELL. The stop is the opposite range boundary and the target is 2R. Maximum one trade per day; any open position is force-closed at 17:15 CET/CEST (broker-time equivalent, DST-aware) before the Xetra close. Day-flat design means no overnight exposure and a structural intraday-DD bound of 1R per day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `orb_minutes` | 60 | 30–120 (multiple of 15) | Duration of the opening range period in minutes |
| `min_range_atr_frac` | 0.15 | 0.05–0.5 | Skip day if ORB range < this fraction of D1 ATR(14) |
| `max_range_atr_frac` | 1.0 | 0.5–3.0 | Skip day if ORB range > this fraction of D1 ATR(14) |
| `rr_multiple` | 2.0 | 1.0–4.0 | TP = entry + rr_multiple × initial risk (opposite boundary distance) |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — DAX 40 index CFD; Xetra cash session provides a well-defined opening range; ~120 trades/yr at index-class commission (~$4.4/trade) is economically viable. Single-symbol by card design (single_symbol_only: true).

**Explicitly NOT for:**
- Other indices — session timing (CET/CEST-based) is specific to Xetra; expanding would require separate session parameters per market and is deferred to P3 per card.
- Forex pairs — no fixed cash session open; ORB thesis requires a discrete range-formation period.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` for ATR(14) range quality filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (M15, via skeleton OnTick); `QM_IsNewBar(_Symbol, PERIOD_D1)` for daily ORB state reset inside Strategy_EntrySignal |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~120 |
| Typical hold time | Minutes to a few hours (intraday only; hard flat before 17:30 CET) |
| Expected drawdown profile | Day-flat: max 1R loss per day; cluster of losing days in choppy regimes |
| Regime preference | Breakout / directional momentum from a compact opening range |
| Win rate target (qualitative) | medium (ORB: target > stop in RR terms; ~40-50% WR typical) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-PROPTRACK-SLATE-2026-07-03`
**Source type:** book + internal evidence
**Pointer:** Crabel, T. (1990). Day Trading with Short Term Price Patterns and Opening Range Breakout. Traders Press. ISBN referenced at https://openlibrary.org/books/OL1611959M/Day_trading_with_short_term_price_patterns_and_opening_range_breakout. Internal replication: QM5_12700 USDJPY 03-06 session-range breakout, PF 1.19 OOS 7yr.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12986_gdaxi-orb-intraday.md`

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
| v1 | 2026-07-04 | Initial build from card | 93a7e406-631e-4d9e-af53-27e8cf436db3 |
