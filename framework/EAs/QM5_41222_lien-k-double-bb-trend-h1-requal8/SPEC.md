# QM5_41222_lien-k-double-bb-trend-h1-requal8 — Strategy Spec

**EA ID:** QM5_41222

**Slug:** `lien-k-double-bb-trend-h1-requal8`

**Source:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_11476`

**Author of this spec:** Codex

**Last revised:** 2026-09-02

---

## 1. Strategy Logic

This EA is a new-identity, mechanically faithful port of
`QM5_11476_lien-k-double-bb-trend-h1`, restricted by the approved manifest to
`USDJPY.DWX`. It uses 20-period inner 1SD and outer 2SD Bollinger envelopes. A
long entry occurs when a completed H1 close transitions into the upper trend
zone between those envelopes; a short entry is symmetric in the lower zone.
The optional filter requires the middle band to slope in the entry direction.

The opposite inner band supplies the structural stop. An invalid band stop
falls back to 40 pips, while a valid stop wider than 60 pips rejects the setup.
There is no fixed target: a completed close back inside the inner neutral
channel exits the position. There is no grid, martingale, averaging,
pyramiding, discretionary input, or ML.

---

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_bb_period` | 20 | Lookback shared by both Bollinger envelopes. |
| `strategy_bb_dev_inner` | 1.0 | Inner deviation defining the neutral boundary. |
| `strategy_bb_dev_outer` | 2.0 | Outer deviation defining the extreme boundary. |
| `strategy_use_slope_filter` | true | Requires middle-band slope to agree with direction. |
| `strategy_slope_bars` | 5 | Middle-band slope comparison gap. |
| `strategy_sl_fixed_pips` | 40.0 | Fallback stop when the band stop is invalid. |
| `strategy_sl_cap_pips` | 60.0 | Maximum accepted dynamic stop distance. |
| `strategy_spread_cap_pips` | 20.0 | Maximum genuine spread; zero modeled spread remains valid. |
| `strategy_no_friday_entry` | true | Prohibits new Friday entries. |
| `strategy_direction_mode` | 0 | `0` both, `1` long only, `-1` short only. |
| `strategy_min_exit_bars` | 0 | Minimum hold before neutral-zone exit; zero preserves card logic. |

---

## 3. Symbol Universe

- `USDJPY.DWX` — exact manifest-bound requalification symbol; active magic
  slot 0 is `412220000`.

The reservation-only recovery card authorizes this single-symbol chain, so no
portable-basket expansion is included in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe references | None |
| Entry gate | `QM_IsNewBar(_Symbol, PERIOD_H1)` |
| Signal inputs | Two completed H1 bars via bounded `QM_ReadBar` calls |

---

## 5. Expected Behaviour

The approved parent card expects about 50 trades per year per symbol. Entries
occur only on completed-bar transitions into a Double-Bollinger trend zone;
positions remain open while price stays outside the neutral channel. This is a
mechanical, low-frequency H1 trend-following sleeve with capped per-trade stop
distance. The expectation is descriptive and asserts no profitability or
pipeline verdict.

---

## 6. Source Citation

**Recovery authority:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_11476`

**Approved mechanics card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_11476_lien-k-double-bb-trend-h1.md`

The source is Kathy Lien, *Battle Tested Forex Trading Strategies*, Double
Bollinger Bands (BKForex Advisors, approximately 2013), source ID
`d0ac3635-33fb-5c22-916b-4b3c77f51bb9`. R1 lineage and R2–R4 PASS are recorded
in the approved parent card. The reserved recovery card is
`D:/QM/strategy_farm/artifacts/cards_review/QM5_41222_lien-k-double-bb-trend-h1-requal8.md`
with `g0_status: APPROVED`. These records authorize build and non-live
requalification only.

---

## 7. Risk Model

| Environment | Active risk | Inactive risk |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live | separately governed `RISK_PERCENT` | `RISK_FIXED=0` |

The bound setfile is backtest-only. This build does not authorize T_Live,
AutoTrading, deployment, or any pipeline verdict.

---

## Revision History

| Version | Date | Reason | Build task |
|---|---|---|---|
| v1 | 2026-09-02 | Initial governed requalification build from approved parent mechanics. | `c2ef7f4a-5b2a-472b-a8bf-6cc4c64acb8b` |
