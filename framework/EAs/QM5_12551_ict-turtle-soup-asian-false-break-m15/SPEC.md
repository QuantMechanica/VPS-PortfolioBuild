# QM5_12551_ict-turtle-soup-asian-false-break-m15 - Strategy Spec

**EA ID:** QM5_12551
**Slug:** `ict-turtle-soup-asian-false-break-m15`
**Source:** `ict-mmm-notes-2020-turtle-soup` (see `D:/QM/strategy_farm/source_cache/ict-twfx-mmm-notes.txt`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA records the fixed Asian-session high and low from 23:00 to 03:00 GMT on M15 bars. During the 07:00-09:00 GMT London window, it first requires a false break of one Asian boundary followed by a close back inside the range. If price then breaks the opposite Asian boundary within eight M15 bars, the EA places a limit order at that broken boundary for three M15 bars, with the stop beyond the first false-break wick plus 0.5 ATR(14).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_asian_start_gmt_hour` | 23 | 0-23 | GMT hour where the Asian range window starts. |
| `strategy_asian_end_gmt_hour` | 3 | 0-23 | GMT hour where the Asian range window ends and is fixed. |
| `strategy_london_start_gmt_hour` | 7 | 0-23 | GMT hour where London kill-zone detection starts. |
| `strategy_london_end_gmt_hour` | 9 | 0-23 | GMT hour where London kill-zone detection ends. |
| `strategy_session_scan_bars` | 160 | 32-240 | Maximum M15 bars scanned to rebuild the Asian range. |
| `strategy_min_asian_bars` | 12 | 1-16 | Minimum Asian-session bars required before a range is valid. |
| `strategy_judas_max_bars` | 8 | 1-16 | Maximum bars after fake-out confirmation for the opposite break. |
| `strategy_pullback_expiry_bars` | 3 | 1-8 | Expiry for the pullback limit order in M15 bars. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the false-break stop buffer. |
| `strategy_atr_sl_mult` | 0.5 | 0.1-3.0 | ATR multiplier added beyond the fake-out wick for the stop. |
| `strategy_breakout_buffer_pips` | 1.0 | 0.0-10.0 | Extra distance beyond the opposite Asian boundary for Judas confirmation. |
| `strategy_rr_fallback` | 2.0 | 0.5-5.0 | Fallback target multiple if prior-day high/low is not beyond entry. |
| `strategy_atr_trail_mult` | 1.0 | 0.1-5.0 | ATR trailing multiplier after TP1 handling. |
| `strategy_max_spread_points` | 80 | 0-500 | Maximum spread allowed for new strategy processing. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX pair with M15 DWX data for Asian/London session structure.
- `GBPUSD.DWX` - card-listed London-session FX pair with direct Asian-range portability.
- `USDJPY.DWX` - card-listed FX pair with M15 DWX data and London liquidity sweeps.
- `XAUUSD.DWX` - card-listed gold symbol with DWX M15 data and liquidity-sweep behavior.

**Explicitly NOT for:**
- `SP500.DWX` - not listed by the card; this EA is built for FX and XAU Asian/London session behavior.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `D1` prior-day high/low for TP1 fallback target selection |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `intraday to one session` |
| Expected drawdown profile | `approximately 15% expected drawdown per card frontmatter` |
| Regime preference | `false-breakout / liquidity sweep` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ict-mmm-notes-2020-turtle-soup`
**Source type:** `educational notes / mentorship model`
**Pointer:** `D:/QM/strategy_farm/source_cache/ict-twfx-mmm-notes.txt`; all R1-R4 PASS per `artifacts/cards_approved/QM5_12551_ict-turtle-soup-asian-false-break-m15.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12551_ict-turtle-soup-asian-false-break-m15.md`

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
| v1 | 2026-06-13 | Initial build from card | de2af3e1-8dd2-449d-b937-d73302207b8c |
