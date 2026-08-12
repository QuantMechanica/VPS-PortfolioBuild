# QM5_20144_ichimoku-atr-cloud-d1 — Strategy Spec

**EA ID:** QM5_20144
**Slug:** `ichimoku-atr-cloud-d1`
**Source:** `BP-UNHOMMEFOU-ICHIMOKU-18242`
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

On each new D1 bar, the EA enters long when Tenkan(9) is above Kijun(26)
and the prior close is more than one ATR(20) above the causally aligned
Ichimoku cloud; the short rule is the exact mirror below the cloud. It uses
the 9/26/65 baseline and exits on an opposite Tenkan/Kijun cross, a frozen
signal-bar cloud-edge stop, the framework kill switch, or Friday close. A
one-time causal cloud-buffer self-test compares each native display-bar span
with its manual calculation 26 bars earlier, and runs only after the tester
has calculated the required D1 history; a mismatch blocks entries. The EA
does not pyramid, average, trail, or use a take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_tenkan` | 9 | fixed at 9 | Tenkan midpoint period. |
| `strategy_kijun` | 26 | fixed at 26 | Kijun midpoint period and cloud displacement. |
| `strategy_senkou_b` | 65 | 52, 65, or 100 | Source-labeled Senkou B variants; 65 is the baseline. |
| `strategy_atr_period` | 20 | fixed at 20 | Wilder ATR period for the cloud-distance filter. |
| `strategy_atr_cloud_mult` | 1.0 | fixed at 1.0 | Required ATR distance beyond the near cloud edge. |

Framework inputs, including the risk, news, stress, seed, and Friday-close
controls, are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — one of the source author's four-major D1 cohort.
- `GBPUSD.DWX` — one of the source author's four-major D1 cohort.
- `USDJPY.DWX` — the source author's reported best performer in the cohort.
- `USDCHF.DWX` — one of the source author's four-major D1 cohort.

**Explicitly NOT for:**

- AUD pairs — explicitly excluded by the source author.
- Symbols outside the four registered FX majors — they have no source-backed
  cohort evidence for this variant.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | Forming-D1 clock with strategy-owned entry, manage, and exit retry latches; all signal values use closed bars. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 12 |
| Typical hold time | several days to several weeks |
| Expected drawdown profile | sparse swing losses with an initial frozen cloud-edge stop; card expectation about 15% |
| Regime preference | sustained D1 trend with price materially beyond the cloud |
| Win rate target (qualitative) | low to medium; payoff is expected from persistent trends |

---

## 6. Source Citation

This card was mechanised from:

- **Source ID:** `BP-UNHOMMEFOU-ICHIMOKU-18242`
- **Source type:** web forum with author-reported 1970–2009 backtests and
  walk-forward selection, recorded as unverified
- **Pointer:** unhommefou (2009), BabyPips thread 18242, posts 25–36,
  <https://forums.babypips.com/t/ichimoku-trading-system/18242>
- **R1–R4 verdict (Q00):** all PASS; see
  `D:/QM/strategy_farm/artifacts/cards_review/QM5_20144_ichimoku-atr-cloud-d1_card.md`

The card labels the frozen signal-cloud stop and post-stop re-arm lock as
house projections. It also records the 9/26/65 selection-bias risk for the
downstream neighborhood-stability gate.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-25 | Initial build from approved card | `11de967c3` |
| v2 | 2026-07-31 | Q02 `ONINIT_FAILED` repair | Deferred the buffer self-test until D1 handles are calculated and restored card-authorized display-bar Senkou alignment; fleet task `4f8a0f72-49f7-4634-88f3-02db9fdfbcb9`. |
