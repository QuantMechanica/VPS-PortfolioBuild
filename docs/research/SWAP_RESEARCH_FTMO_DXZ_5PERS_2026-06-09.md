# Swap / Overnight-Financing — FTMO · Darwinex Zero · The 5%ers

**Author:** Claude · **Date:** 2026-06-09 · **Status:** research brief (feeds a future `live_swap.json`, analog to `live_commission.json`)
**Method:** 3 parallel web-research agents, official-source-prioritized, no-invented-values. Sources cited inline + at end.

## ★ Headline finding (applies to ALL THREE firms)

**None of the three publishes a static, citable per-instrument swap table.** Every official page
defers to the **MT5 platform symbol Specification** (`Market Watch → right-click symbol → Specification
→ Swap Long / Swap Short / swap mode / 3-day-swap`). Swaps are **asymmetric long/short**, **reset daily**,
and "change without prior notice." So the ONLY rule-compliant (no-invented-values) route to real
per-instrument numbers is a **dated snapshot of the MT5 symbol spec**, not a web figure.

Second hard fact (already in our evidence base): our `.DWX` custom backtest symbols apply **$0 swap**
in the tester (`Net == GrossP+GrossL`, [[project_qm_backtests_cost_free_2026-05-29]]). So swap, like
commission, must be **INJECTED** into the model — it is not read from the tester for custom symbols.

## Per-firm summary

### Darwinex Zero (DXZ) — our PRIMARY live target
- **Charges swaps: YES.** DXZ swaps = the **underlying Darwinex live-broker swaps** applied to the
  signal account (you're "never charged to your credit card", but the swap hits the DARWIN/signal P&L).
  → **Model DXZ swap = Darwinex live-account swap.** (DXZ doc "Trading commissions and swaps", last-updated 2023-03-31.)
- **Model:** per-lot cash $/lot/night = `table_value × contracts`; FX = interest-rate differential **+ LP markup**;
  asymmetric (LP markup both sides). No swap-free / Islamic option documented.
- **Settlement:** daily **17:00 New York = 21:00 UTC** rollover (matches our broker-time convention).
- **Triple-swap day:** **Wednesday** (FX + indices); **Friday for GOLD (XAUUSD)**. (Confirmed in DXZ commodity-P&L doc.)
- **Symbol-name mapping (load-bearing for our `.DWX` symbols):** Darwinex uses **SP500** (not US500),
  **GDAXI** (not GER40/DE40), **WS30** (not US30); FX + **XAUUSD** + **NDX** same. (Darwinex Help "Assets available".)
- **Live values:** only in `darwinex.com/spreads/{forex,indices,commodities}` (JS-gated) + the Darwinex MT5 spec. No citable static numbers obtained.

### FTMO
- **Charges swaps: YES** on standard accounts. **Swing** account removes overnight/weekend/news
  *restrictions* but is **NOT officially stated to be zero-swap** (secondary reviews claim it — unconfirmed).
  Islamic/swap-free = eligibility-gated, mechanics unconfirmed in FTMO's own FAQ.
- **Model unit differs by entity:** FTMO.com (global, MT5) = **points/lot/night**; FTMO-US/OANDA = **% of notional**. Asymmetric; often negative both directions.
- **Triple-swap day:** **Wednesday→Thursday** for FX (officially). No official Friday-for-indices rule (industry convention, unconfirmed by FTMO).
- **Index swaps embed dividend adjustments** → large, lumpy, the most volatile component of the universe.
- **Only ONE official concrete value:** EURUSD **−6.25 long / −3.00 short points/lot** (illustrative blog example, mod 2026-02-18) ⇒ ≈ −$6.25/−$3.00 per lot/night. No official values for JPY pairs, gold, or indices (a forum-only US100 ≈ −$276 long / −$138 short/day is **secondary/undated — not citable**).

### The 5%ers
- **Charges swaps: YES, by default** on all evaluation + funded forex/CFD programs ("collected and/or paid nightly").
- **Swap-free: opt-in only**, **Funded stage only**, via Islamic-account **request** to support — NOT a
  blanket published policy. A claimed "additional fee" for the Islamic account is unconfirmed (ambiguous).
- **Triple-swap day CHANGED: Wednesday → FRIDAY** (~2026-04-02, secondary source thegodfunded.com; verify in-platform).
- **Model:** standard MT5 broker-feed swap (per-instrument, asymmetric); **undisclosed liquidity providers**
  (no named broker to cross-check) → in-terminal MT5 snapshot is the only citable source.
- **No per-instrument table published.** Only quantified figure anywhere is crude oil (−$20/day, ×10 weekend) — outside our universe.

## Implications for the QM cost model

1. **Swap matters only for positions held overnight.** Intraday edges (e.g. ORB, EOD-flat) → swap ≈ 0.
   Multi-day / structural / swing holds (e.g. Turnaround-Tuesday class) → swap is material and currently **unmodeled (=$0)**.
2. **Triple-day logic is instrument-specific:** DXZ Wed (FX/index) + **Fri (gold)**; FTMO Wed→Thu (FX);
   5%ers now **Fri**. A swap model must apply the ×3 on the correct day per symbol class.
3. **Worst-case envelope** (analog to `live_commission.json` `_authority: worst-case{DXZ,FTMO}`): take the
   **most-negative** long/short per symbol across the three firms' MT5 specs → conservative constant.
4. **Citable source = MT5 symbol Specification snapshot, dated to a CSV.** DXZ (our live target) is the
   primary feed; pull Swap Long/Short from a **Darwinex/DXZ MT5 terminal** (NOT our `.DWX` factory symbols,
   which carry $0 swap) → that becomes the evidence file backing a `live_swap.json`.

## Recommended next step (OWNER decision — touches the hard-bounded cost model)

Build **`framework/registry/live_swap.json`** (mirror of `live_commission.json`): `_authority` =
worst-case{DXZ, FTMO, 5%ers} from a dated MT5-spec snapshot; per-symbol-class long/short $/lot/night;
triple-day map (Wed FX/index, Fri gold). Then inject swap into Q04/Q08 **by holding-period** from the
per-trade stream (each trade has open/close ts → overnight-count × swap, ×3 on the triple day). This is
the natural completion of DL-073 (cost realism) — but only worth it for the multi-day-hold cohort; intraday
EAs are unaffected. **Values are NOT yet obtainable from the web** (all JS-gated/platform-only) → step 1 is
a Darwinex-MT5 symbol-spec snapshot.

## Sources
**DXZ/Darwinex:** [DXZ commissions & swaps (2023-03-31)](https://darwinexzero.document360.io/docs/trading-commissions-and-swaps) · [Darwinex Help — execution costs](https://help.darwinex.com/execution-costs) · [Darwinex Help — assets/symbol names](https://help.darwinex.com/assets-available) · [DXZ commodity P&L — gold Friday triple](https://darwinexzero.document360.io/docs/profit-loss-trade-commodities) · live (gated) [forex](https://www.darwinex.com/spreads/forex)/[indices](https://www.darwinex.com/spreads/indices)/[commodities](https://www.darwinex.com/spreads/commodities)
**FTMO:** [What is a swap (EURUSD −6.25/−3.00, Wed→Thu; mod 2026-02-18)](https://ftmo.com/en/blog/what-is-a-swap-and-for-whom-is-it-important/) · [Symbols (dynamic spec)](https://ftmo.com/en/symbols/) · [Swing account FAQ](https://ftmo.com/en/faq/ftmo-swing-account-type/) · [FTMO×OANDA — %notional FX swap](https://ftmo.oanda.com/blog/what-is-a-swap-and-who-is-it-important-for/)
**The 5%ers:** [Spreads & commissions (updated 2026-02-01)](https://help.the5ers.com/what-are-the-spreads-and-commissions/) · [Swap-free/Islamic (2025-03-28)](https://help.the5ers.com/does-the5ers-offer-swap-free-accounts-islamic-accounts/) · [Asset specs](https://the5ers.com/asset-specifications/) · [Wed→Fri triple change (secondary, 2026-04-02)](https://thegodfunded.com/en/news/the5ers-alters-swap-charge-schedule-multi-day-swaps-shift-to-fridays)
