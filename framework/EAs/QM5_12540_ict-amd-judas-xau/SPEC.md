# QM5_12540_ict-amd-judas-xau — Strategy Spec

**EA ID:** QM5_12540
**Slug:** ict-amd-judas-xau
**Source:** ict-2022-model-canonical-2026-06-12 (see `strategy-seeds/sources/ict-2022-model-canonical-2026-06-12/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA measures the broker-time Asia range from 01:00 through 09:00 on M15 bars. It skips the day when that range is too small or too large versus H1 ATR(14). During 09:00 through 11:00, it watches for a closed M15 bar outside the Asia range, then enters in the opposite direction if price closes back inside the range within the next four M15 bars. The initial stop is beyond the Judas extreme plus 0.3 x M15 ATR(14), TP1 is the opposite Asia extreme, and the runner target is 1.5 x range height beyond that extreme capped at 3R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_asia_start_hour` | 1 | 0-23 | Broker hour when the Asia accumulation range starts. |
| `strategy_asia_end_hour` | 9 | 1-24 | Broker hour when the Asia accumulation range ends. |
| `strategy_judas_start_hour` | 9 | 0-23 | Broker hour when false breaks may start. |
| `strategy_judas_end_hour` | 11 | 1-24 | Broker hour after which new false breaks are ignored. |
| `strategy_failure_bars` | 4 | 1-16 | Maximum M15 bars allowed for the close back inside the range. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for range filter and stop padding. |
| `strategy_min_range_atr_mult` | 0.5 | 0.1-5.0 | Minimum Asia range height versus H1 ATR. |
| `strategy_max_range_atr_mult` | 2.5 | 0.1-10.0 | Maximum Asia range height versus H1 ATR. |
| `strategy_stop_atr_mult` | 0.3 | 0.0-5.0 | M15 ATR padding beyond the Judas extreme. |
| `strategy_max_risk_atr_mult` | 2.0 | 0.1-10.0 | Skip signal when stop distance exceeds this multiple of M15 ATR. |
| `strategy_runner_range_mult` | 1.5 | 0.1-10.0 | Runner target extension beyond the opposite Asia extreme. |
| `strategy_max_rr` | 3.0 | 0.5-10.0 | Maximum runner target distance in R multiples. |
| `strategy_partial_close_percent` | 50.0 | 1.0-99.0 | Portion closed at TP1. |
| `strategy_time_exit_hour` | 21 | 0-23 | Broker hour for same-day strategy time exit. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — primary card market for London-open Judas fades on gold.
- `GBPUSD.DWX` — card-listed FX market with London session liquidity and the same M15 range structure.

**Explicitly NOT for:**
- `SP500.DWX` — not listed by the card and uses different exchange-session structure.
- `NDX.DWX` — not listed by the card and uses different index-session liquidity.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` ATR(14) for the Asia-range size filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | Same-day intraday; entry after London-open re-close, time exit at 21:00 broker |
| Expected drawdown profile | `10%` expected DD from card frontmatter |
| Regime preference | London-open false-break mean reversion after Asia-range manipulation |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ict-2022-model-canonical-2026-06-12`
**Source type:** video
**Pointer:** `https://www.youtube.com/@InnerCircleTrader` and `artifacts/cards_approved/QM5_12540_ict-amd-judas-xau.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12540_ict-amd-judas-xau.md`

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
| v1 | 2026-06-12 | Initial build from card | 47a62071-38bd-4aff-be52-0c1acbe01889 |
