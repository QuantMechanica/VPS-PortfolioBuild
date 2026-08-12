# QM5_11461_goodwin-j-outside-bar-daily-reversion-d1 — Strategy Spec

**EA ID:** QM5_11461
**Slug:** `goodwin-j-outside-bar-daily-reversion-d1`
**Source:** `038d2a5d-1c89-5745-afdb-2cd76b623b77` (see `strategy-seeds/sources/038d2a5d-1c89-5745-afdb-2cd76b623b77/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Outside-bar exhaustion fade. An outside bar (`High[1]>High[2]` and
`Low[1]<Low[2]`) that closes beyond the prior day's extreme is treated as a
short-term reversal signal: if the outside bar's close is below the prior
day's low (bearish close), buy the next D1 open expecting a bounce; if the
close is above the prior day's high (bullish close), sell the next D1 open.
Setups where the outside bar itself falls on a Friday are skipped. Stop-loss
is a fixed `strategy_sl_pips` (200) distance per Goodwin's original design;
there is no discretionary take-profit — the position is force-closed after
`strategy_hold_bars` (1) additional closed D1 bar regardless of P&L (P2
simplification of Goodwin's "exit next bar if in profit, else hold one more
bar" rule).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sl_pips` | 200 | fixed | Hard stop-loss distance in pips (Goodwin's original) |
| `strategy_hold_bars` | 1 | fixed | Bars held since entry before forced time exit (P2 1-bar-hold simplification) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Goodwin's primary instrument (2010-2019 backtest)
- `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `USDCAD.DWX` — card's R3 basket extension

**Explicitly NOT for:**
- Any symbol outside the five listed DWX FX majors — no R3 basis asserted.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8 |
| Typical hold time | 1 D1 bar |
| Expected drawdown profile | rare wide-SL losses (200 pips) offset by frequent small reversion wins |
| Regime preference | mean-revert |
| Win rate target (qualitative) | high (Goodwin cites 88% on EURUSD 2010-2019; unverified in V5 pipeline) |

---

## 6. Source Citation

**Source ID:** `038d2a5d-1c89-5745-afdb-2cd76b623b77`
**Source type:** book / guidebook
**Pointer:** Jarrod Goodwin, "Beat the Markets Strategy Guidebook", thetransparenttrader.com (~2020); original concept Larry Williams, "Long-Term Secrets to Short-Term Trading" (1999) (local PDF: 622374394-Beat-the-Markets-Strategy-Guidebook.pdf)
**R1–R4 verdict (Q00):** R1 TIER_C (informational per OWNER 2026-07-23 policy), R2/R3/R4 PASS — see `artifacts/cards_approved/QM5_11461_goodwin-j-outside-bar-daily-reversion-d1.md`

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
| v1 | 2026-08-10 | Initial build from card | build_ea task d683a46f-5e83-48fc-bccd-9106e8f3f489 |
