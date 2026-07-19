---
strategy_id: INVESTUI-FRIDAY-GOLD-2026
source_id: INVESTUI_EFFECTS_SOURCING_2026-07-19
ea_id: QM5_20010
slug: xau-friday-rush
type: strategy
status: DRAFT
source_citation: "Yu, H-C.; Lee, C-J.; Shih, T-L. (2016). Weekday effects on gold: Tokyo, London, and New York markets. Banks and Bank Systems 11(2), 33-44. DOI 10.21511/BBS.11(2).2016.04. Weekend-decay nuance: Blose/Gondhalekar (2013), Accounting & Finance 53(3), DOI 10.1111/j.1467-629X.2012.00497.x. Mechanism context: Draper/Faff/Hillier (2006), FAJ 62(2), DOI 10.2469/faj.v62.n2.4085. Vendor secondary: investui.com Friday-Gold-Rush page (rule verbatim, no numeric stats published)."
sources:
  - "Yu/Lee/Shih 2016 (DOI 10.21511/BBS.11(2).2016.04) — Friday gold returns positive+significant"
  - "Blose/Gondhalekar 2013 (DOI 10.1111/j.1467-629X.2012.00497.x) — weekend hold decays; exit Friday close"
  - "Draper/Faff/Hillier 2006 (DOI 10.2469/faj.v62.n2.4085) — safe-haven mechanism context"
  - "investui.com rendite-friday-gold-rush-effekt (vendor claims, tier C)"
concepts:
  - gold-friday-day-of-week-effect
  - jewellery-physical-friday-buying
  - weekend-safe-haven-demand
  - no-weekend-hold
indicators:
  - atr-14-d1
target_symbols: [XAUUSD.DWX]
primary_target_symbols: [XAUUSD.DWX]
period: D1
timeframes: [D1]
expected_trade_frequency: "One long per Friday D1 bar, holidays skipped. Declared 50 trades per year per symbol."
expected_trades_per_year_per_symbol: 50
risk_class: medium
ml_required: false
single_symbol_only: true
priority_track: true
created: 2026-07-19
created_by: claude-board-advisor
last_updated: 2026-07-19
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
g0_status: APPROVED
g0_approval_reasoning: "R1 PASS: peer-reviewed primary Yu/Lee/Shih 2016 (DOI 10.21511/BBS.11(2).2016.04) + Blose/Gondhalekar 2013 weekend-decay nuance. R2 PASS: pure calendar rule, one robustness knob, no fitting surface. R3 PASS: XAUUSD.DWX D1 full history. R4 PASS: no ML. investui wave (OWNER 2026-07-19); TT/month-end/po"
expected_pf: 1.15
expected_dd_pct: 10.0
---

# Strategy Card — XAU Friday Gold Rush (Friday D1 bar long)

> Sourced 2026-07-19 from the OWNER-directed investui market-effects analysis
> (4 effects screened, 3 rejected: Turnaround-Tuesday=duplicate of QM5_13137 family,
> month-end=duplicate of QM5_20004 window family, Pound-Shorter=cost-dead FX).
> Full brief: session scratchpad `investui/friday-gold_brief.md`.

## 1. Concept & Primary Sources

Gold exhibits systematically positive returns on the Friday weekday bar
(Thursday close to Friday close). Documented drivers: jewellery-industry Friday
physical buying (weekend/Monday delivery) plus weekend safe-haven insurance
demand.

Primary literature (load-bearing citations):
- Yu, H-C.; Lee, C-J.; Shih, T-L. (2016). Weekday effects on gold: Tokyo, London,
  and New York markets. Banks and Bank Systems 11(2), 33-44.
  DOI 10.21511/BBS.11(2).2016.04 — Friday gold returns positive and significant.
- Blose, L.E.; Gondhalekar, V. (2013). Weekend gold returns in bull and bear
  markets. Accounting & Finance 53(3), 609-622.
  DOI 10.1111/j.1467-629X.2012.00497.x — the WEEKEND hold (Friday close to Monday
  close) shows significantly LOWER returns, so this card captures exactly the
  Friday bar and is always flat over the weekend.
- Draper, P.; Faff, R.; Hillier, D. (2006). Do Precious Metals Shine? Financial
  Analysts Journal 62(2), 98-106. DOI 10.2469/faj.v62.n2.4085 — mechanism context.
- Vendor secondary (tier C): https://www.investui.com/de-de/investieren/geldanlage/rendite-friday-gold-rush-effekt/gold-preis-kaufen

## 2. Markets & Timeframes

- Symbol: XAUUSD.DWX (gold, cheapest cost class — the same 50/yr density on FX
  would die on costs)
- Timeframe: D1 native (no MN1/monthly logic). Broker time NY-close (GMT+2
  winter / GMT+3 US DST) — the D1 Friday bar IS the literature's Friday return.

## 3. Entry Rules

```text
- long-only; at the OPEN of the Friday D1 bar (first tick after Thursday D1 close)
- BUY at market
- protective Stop (non-alpha sizing backstop): strategy_stop_atr_mult * ATR(D1, 14)
- skip if Friday is a market holiday / no D1 bar forms
- news blackout per framework default
```

## 4. Exit Rules

```text
- time exit at the CLOSE of the same Friday D1 bar (before weekend) — always flat over the weekend
- SL = catastrophe stop only; no TP (the edge is the calendar bar, not a level)
- no trailing, no partials; Friday-Close hard rule is inherently satisfied (position closes at Friday close by design)
```

## 5. Filters (No-Trade)

```text
- only the Friday D1 bar; no other weekday entries
- optional OOS-reserved (NOT baseline): skip if close < SMA(50, D1) — Stagge notes edge strongest in weak gold regimes; baseline stays unconditional per the primary literature
```

## 6. Parameters To Test (P3 Sweep)

```yaml
- name: strategy_stop_atr_mult
  default: 3.0
  sweep_range: [2.0, 3.0, 4.0]
```

(Deliberately minimal: one robustness knob. Entry/exit timing is structural
calendar logic, not tunable — no timing sweep, no fitted thresholds.)

## 7. Author Claims (verbatim, labeled)

```text
investui (vendor, no numbers published): "Donnerstagabends Gold kaufen und die
Position 24-Stunden halten"; charts "10 Jahre, teilweise basierend auf einem
Backtest"; claims outperformance vs buy-and-hold esp. since 2012. VENDOR CLAIM.
Yu/Lee/Shih (2016): Friday shows positive and significant higher gold returns;
Tuesday negative and significant. (paper finding, 3 markets)
Blose/Gondhalekar (2013): weekend gold returns (Fri close -> Mon close)
significantly lower than rest of week, 1975-2011, bear-market driven. (paper finding)
```

## 8. Initial Risk Profile

```yaml
expected_pf: 1.15
expected_dd_pct: 10
expected_trade_frequency: 50/year
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

Cost math (venue_cost_model.json 2026-07-19, sourced): gold commission = 0.005%
of notional round-trip (0.0025%/side, $0 floor) — identical on Darwinex Zero
(tester Groups `Commodities\*` CommissionValue=0.0025 Mode=4; official
help.darwinex.com/execution-costs) and FTMO (metals 0.0025%/side). At RISK_FIXED
$1,000 with a 3xATR D1 stop (~0.03-0.06 lot, ~$13-24k notional) realised
commission is ~$0.7-1.2 RT/trade. Spread is embedded in the .DWX real-tick
history (backtests are spread-inclusive; only commission needs injection at the
net gate). Literature Friday drift ~5-10 bps (~$6-24 gross at this sizing) vs
~$1-2 commission = comfortable cushion; the same 50/yr density on FX would pay
~$5-6.35/lot RT commission and be marginal. Swap irrelevant (flat over every
weekend by design). Net-of-cost Q04 remains the binding gate; post-publication
decay (primary sample ends ~2014) is the main kill risk — Q02 full history
measures it first.

## 9. Framework Alignment

```yaml
modules_used:
  no_trade: { used: true, notes: "Friday-only calendar gate, holiday skip, news default" }
  trade_entry: { used: true, notes: "Friday D1 bar open, long only" }
  trade_management: { used: false, notes: "none" }
  trade_close: { used: true, notes: "time exit at Friday D1 close; QM_EXIT_STRATEGY" }
hard_rules_at_risk: []
at_risk_explanation: |
  Friday Close: satisfied by construction (flat at Friday close). No ML, no grid,
  no scalping, single position per magic.
```

## 10. Overlap Statement (dedupe, verified 2026-07-19)

DISTINCT from: QM5_20004 TOM (monthly axis, index), QM5_13137 breadth-tue
(Tuesday index reversal), QM5_13207 ws30-fri (Friday INDEX intraday session,
different asset+mechanism), QM5_12974 XAU-Asia-drift (intraday session axis, not
day-of-week; potential mild correlation on gold exposure — Q09 correlation screen
decides), brent-fri-prem (oil). No existing card trades the gold day-of-week axis.

## 11. Lessons / kill criteria

```text
- Q02 full-history gross PF < 1.20 -> RETIRE (no parameter rescue; the calendar
  rule has no fitting surface by design).
- Q04 net-of-cost must confirm the 2-3x cushion; net PF < 1.10 -> RETIRE.
- Q09: watch gold-cluster concentration vs the live book's XAU sleeves.
```
