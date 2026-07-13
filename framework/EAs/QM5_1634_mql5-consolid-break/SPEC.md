# QM5_1634_mql5-consolid-break — Strategy Spec

**EA ID:** QM5_1634
**Slug:** `mql5-consolid-break`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (MQL5 article 15311)
**Author of this spec:** Codex
**Last revised:** 2026-07-12

---

## 1. Strategy Logic

On each completed H1 bar, the EA measures the high-low range of the preceding
`range_lookback` bars, excluding the signal bar. The range qualifies as a
consolidation when it contains at least `range_min_bars` and is no wider than
`range_max_atr` times the square-root-scaled ATR baseline. A close above the
range buys; a close below it sells. The initial stop is beyond the range or at
least `atr_sl_mult` ATR from entry, the target is `rr_target` times initial
risk, and the optional deterministic exit is a close back through the entry
range midpoint.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `range_lookback` | 20 | 10-40 | Completed bars used to define the consolidation. |
| `range_min_bars` | 10 | 5-20 | Minimum valid bars required in the range. |
| `range_max_atr` | 1.5 | 1.0-2.5 | Maximum range width versus the square-root-scaled ATR baseline. |
| `atr_sl_mult` | 1.0 | 0.75-2.0 | Minimum initial stop distance in ATR units. |
| `rr_target` | 2.0 | 1.0-2.5 | Take-profit distance in initial-risk units. |

Framework inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid primary FX carrier for the repaired Q02 handoff.
- `GBPUSD.DWX` — second liquid FX carrier authorized by the approved card.
- `XAUUSD.DWX` — card-authorized metal comparison, deferred behind the FX lane.

**Explicitly NOT for:**

- Index CFDs — the approved card names only the two FX carriers and gold.
- Symbols outside the active magic registry — their slot/risk contract is undefined.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()`; range scan occurs once per completed H1 bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 20 (farm Q02 contract) |
| Typical hold time | hours to days, bounded by stop, target, or midpoint exit |
| Expected drawdown profile | episodic fixed-risk losses around failed volatility expansions |
| Regime preference | volatility contraction followed by directional breakout |
| Win rate target (qualitative) | low-to-medium, offset by the 2R target |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** named technical article
**Pointer:** Allan Munene Mutiiria, “Developing an Expert Advisor (EA) based on
the Consolidation Range Breakout strategy in MQL5,” 2024-07-17,
https://www.mql5.com/en/articles/15311
**R1–R4 verdict (Q00):** all PASS per the approved farm card
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1634_mql5-consolid-break.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by the portfolio process |

ENV-to-mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-26 | Initial build from approved card | Original farm build. |
| v1.1 | 2026-07-12 | Q02 infrastructure recovery | Corrected impossible breakout window, minimum-length logic, DWX range scaling, framework ordering, setfile contract, and stale binary. |
