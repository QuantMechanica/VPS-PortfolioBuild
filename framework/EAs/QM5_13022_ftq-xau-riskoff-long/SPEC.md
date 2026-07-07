<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_13022_ftq-xau-riskoff-long — Strategy Spec

**EA ID:** QM5_13022
**Slug:** `ftq-xau-riskoff-long`
**Source:** `BL-SAFEHAVEN-2010` (see `strategy-seeds/sources/BL-SAFEHAVEN-2010/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

Long-only XAUUSD D1 breakout, active only during equity risk-off regimes.
Entry requires three conditions on the same D1 close: (1) a cross-symbol
regime gate — the regime symbol's (default SP500.DWX, data-only, never
traded) D1 close is below its own SMA(200), i.e. equities are in a bear
regime; (2) a gold own-momentum gate — XAUUSD D1 close above its own
SMA(50), confirming the flight-to-quality bid is already visible in gold
itself (guards against liquidation-cascade phases like March 2020 where gold
sells off with equities); (3) the trigger — XAUUSD D1 close breaks above its
Donchian(20) high of the prior bars. Exit on any of: ATR(14)x2.5 hard stop,
regime-flip (regime symbol closes back above its SMA(200)), a D1 close below
the Donchian(10) low (channel trail), or a 60-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_regime_symbol` | SP500.DWX | fixed (data input) | cross-symbol equity regime read, never traded; live preset MUST override with the broker's equivalent equity index |
| `strategy_regime_sma` | 200 | 150-250 | SMA period on the regime symbol defining the bear/bull equity regime boundary |
| `strategy_mom_sma` | 50 | 30-100 | SMA period on XAUUSD defining the gold own-momentum gate |
| `strategy_donchian_entry` | 20 | 15-30 | Donchian high lookback (prior bars) for the entry breakout trigger |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR multiple from entry price for the hard stop distance |
| `strategy_donchian_trail` | 10 | 8-15 | Donchian low lookback for the channel-trail exit |
| `strategy_max_hold_bars` | 60 | 40-80 | Maximum D1 bars held before the time-stop exit fires |
| `strategy_max_spread_points` | 80 | 50-120 | Maximum spread (points) allowed for a new entry |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — the only traded symbol (`single_symbol_only: true`); gold is
  the safe-haven asset whose flight-to-quality bid is isolated by the regime
  gate. Verified in the DWX symbol matrix with D1 history 2017-2026 on T1-T5.

**Explicitly NOT for (card forbids multi-symbol expansion):**
- `SP500.DWX` — read-only regime DATA input, never traded, carries no magic
  slot. Backtest-only custom symbol (broker does not route orders on SP500);
  live deployment must override `strategy_regime_symbol` with a live-routable
  equity index equivalent.
- No other symbols — the card explicitly sets `single_symbol_only: true` and
  does not call for portable-basket expansion; P2 will use 1 terminal for
  this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none — cross-SYMBOL (not cross-TF) regime read on the same D1 period |
| Bar gating | `QM_IsNewBar()` (host chart XAUUSD.DWX D1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6 (approximately 4-9 entries/year) |
| Typical hold time | up to 60 D1 bars (time stop), episodic — most positions closed earlier by regime-flip, trail, or ATR stop |
| Expected drawdown profile | expected_dd_pct 15.0; episodic clustering in equity risk-off episodes (2018Q4, 2020, 2022) |
| Regime preference | breakout, gated to equity bear-regime / risk-off episodes |
| Win rate target (qualitative) | medium — expected_pf 1.15 |

---

## 6. Source Citation

**Source ID:** `BL-SAFEHAVEN-2010`
**Source type:** paper
**Pointer:** Baur, Dirk G. and Brian M. Lucey. "Is Gold a Hedge or a Safe
Haven? An Analysis of Stocks, Bonds and Gold." The Financial Review, 45(2),
2010. https://onlinelibrary.wiley.com/doi/10.1111/j.1540-6288.2010.00244.x —
supplemented by Baur, Dirk G. and Thomas K. McDermott. "Is gold a safe haven?
International evidence." Journal of Banking & Finance, 34(8), 2010.
https://www.sciencedirect.com/science/article/pii/S0378426609003343
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_13022_ftq-xau-riskoff-long.md`

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
| v1 | 2026-07-07 | Initial build from card | ffd769b7-bf7b-41f6-9063-b67f6630822e |
