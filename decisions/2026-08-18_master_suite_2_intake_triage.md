# Intake triage — OWNER drop `Strategy_Cards_Overview_2.md` (Master Suite 2, 20 cards)

**Date:** 2026-08-18 · **Decider:** Claude · **Source:** `C:\Users\Administrator\Desktop\Strategy_Cards_Overview_2.md`
(25,911 bytes, 437 lines, dated 18 August 2026, self-labelled *"G0 APPROVED / PRODUCTION BLUEPRINTS"*)

**Disposition: 0 approved · 20 rejected · 0 deferred.** Every card resolves either to an
already-approved card in the reservoir or to a line this factory closed with evidence. The
extractable value is real but it is **parameter variants for incumbent cards**, not new EA ids —
recorded in §4.

This follows the intake recipe ratified for the 2026-08-15 Century drop
(`decisions/2026-08-15_century_suite_intake_triage.md`): triage first, never adopt the overview's
own numbers.

## 0. The document's own quality claims are not evidence

The closing R1–R4 table self-certifies all four gates. R1 is asserted as *"verifizierte
Myfxbook-Audits, MQL5-Live-Signale, YouTube-Stresstests"* with no artefact, and Säule XV headlines a
*"$10k → $9M Backtest Benchmark"*. Under the Hard Rule *evidence over claims* these carry no weight,
exactly as the Century drop's fabricated PF/win-rate table did. The triage below rests only on our
own artefacts.

R2 is additionally **false as written** for Säule XV: the pillar prescribes *"Execution Randomization
für Prop Firms (1–3 Pips Zufallsvariation bei TP/SL zur Verhinderung von Copy-Trading-Erkennung)"*.
That is non-deterministic by construction, so it contradicts the same document's R2 = PASS, and it is
detection-evasion rather than a trading mechanic. It would not be built regardless of the dedup
outcome.

## 1. Säule XIII — "The Gold Reaper", 9 XAUUSD cards (QM5_42001–42009): **REJECT, closed line**

Gold Reaper was investigated in full on 2026-07-23 (14-agent mining workflow, dossier
`docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md`, commit `d52584351`, revised `30c0ee5fd`
after a Codex cross-challenge). **Verdict: do not clone.** It was rejected a second time in the
Century intake as `31008 Gold Reaper` (closed line).

The decisive point is that this drop reproduces the exact error the dossier identified. The
primary source — Wim Schrynemakers' own Darwinex interview (`Q4LJyCn9_kA`, transcript fetched) —
states the "9 strategies" are **multiple pending orders at ONE S/R zone with varied exit
management**, i.e. one over-parameterised breakout. Splitting that into nine independent EA ids
would mint nine magic numbers for one mechanic and nine separate Q02–Q10 chains for it.

Per-card, each also has an incumbent:

| card | mechanic | incumbent |
|---|---|---|
| 42001 | London opening-range XAU | `QM5_10140` london-session-break, `QM5_1120` big-ben |
| 42002 | US pit-open momentum XAU | `QM5_10181` tv-xau-ny-orb-retest |
| 42003 | Asian consolidation range | `QM5_10715` tv-asian-box, `QM5_11369`, `QM5_10092` |
| 42004 | prior-day D1 high/low extension | `QM5_10007` ff-prevday-breakout-edge, `QM5_12561` |
| 42005 | 24-period H1 Donchian | `QM5_10229` tv-donchian-base, `QM5_10347`, `QM5_1635` |
| 42006 | midday overlap breakout+retest | `QM5_10659` tv-orb-retest |
| 42007 | order-block liquidity sweep | SMC/ICT closed line; `QM5_1050`, `QM5_10656` |
| 42008 | Bollinger-inside-Keltner squeeze | `QM5_10395` et-ttm-squeeze — **already carries XAUUSD.DWX**; the Century drop's `41012` was rejected against this same card |
| 42009 | H4 EMA 50/200 trend pullback | generic trend-pullback; no distinguishing mechanic |

The dossier's retained disposition stands unchanged: one pre-registered `XAU_EVENT_VOL_BREAKOUT`
hypothesis with `10181` and Balke as mandatory controls. This drop does not advance it.

## 2. Säule XV — "Gold Breakout Engine" (Balke/Traders Meta), 4 XAUUSD cards (QM5_44001–44004): **REJECT, closed line**

The Balke range-breakout was walked forward. Read straight out of
`D:/QM/reports/balke_walkforward/result.json`:

| leg | trades | net | MaxDD | PF | DD/net |
|---|---:|---:|---:|---:|---:|
| USDJPY OOS | 795 | +$68,235 | −$19,853 | **1.20** | 0.29× |
| **XAU OOS** | 970 | +$13,342 | −$40,645 | **1.03** | **3.05×** |

**USDJPY survived; the XAU transfer `QM5_13213` was killed.** (The `QM5_12832` card quotes the
USDJPY leg as net PF 1.19 / Sharpe 1.84 / MaxDD 2.38% — a net-of-cost restatement of the same run;
the 1.20 above is the figure in the results file.) Gold is the leg that died, and this pillar is
four more of it on the same symbol.

| card | mechanic | incumbent / basis |
|---|---|---|
| 44001 | 02:00–07:00 GMT range → 07:00 pending stops | Balke's own fix-window form on XAU = `QM5_13213`, killed |
| 44002 | rolling N=36 H1 swing breakout | `QM5_12914` xau-weekly-donchian-swing, `QM5_1635` |
| 44003 | NY 11:00–13:00 range → 13:00 expansion | `QM5_10181` tv-xau-ny-orb-retest |
| 44004 | D1 extreme continuation | `QM5_10007` ff-prevday-breakout-edge |

Plus the execution-randomisation wrapper in §0.

## 3. Säule XIV — "Ultimate Breakout System", 7 multi-asset cards (QM5_43001–43007): **REJECT, duplicates**

This is the only pillar with non-XAU content, so each card was deduped individually against the
3,279 approved card bodies rather than by pillar.

| card | claimed mechanic | incumbent | why it is the same card |
|---|---|---|---|
| 43001 | Asian box 00:00–06:45, stops at 06:55, FX majors | `QM5_11369` london-asian-range-breakout-m15; also `QM5_10715`, `QM5_1120` | same box, same M15, same London-open trigger; differs only in buffer (2.0 pips) and cancel time |
| 43002 | London 08:00–08:30 range + ADX>25 | `QM5_10958` ftmo-ib-brk (`EURUSD, GBPUSD, NDX, WS30`) | "initial balance breakout" **is** the first-period-after-open range; ADX>25 is a filter parameter |
| 43003 | WM/Reuters 16:00 fix pre-breakout | `QM5_32007` london-fix-wm-reuters-currency-drift (**M5, EURUSD+GBPUSD, APPROVED**) and `QM5_20034` wmr-postfix | 32007 already trades momentum into the 16:00 fix on the same symbols and timeframe; 20034 covers the post-fix fade with a peer-reviewed citation (Evans 2018, JBF 87:233-247) |
| 43004 | US indices 15-min ORB | `QM5_11153` qc-orb30 — `target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]`, **exactly this basket** | identical card at a 30-minute range; 15 vs 30 min is a setfile parameter, not a strategy |
| 43005 | DAX Frankfurt pre-market velocity | `QM5_12832` dax-range-breakout (fork of the surviving `QM5_12700`) | 12832 already names both windows as its sweep: *"(a) overnight/pre-open broken at the 09:00 cash open; (b) opening-range (first 15–30 min after the open)"* — 43005 is variant (a)+(b) |
| 43006 | WTI NYMEX pit open 14:00–14:30 GMT | `QM5_10354` et-crude-orb | 10354's **range B is 14:00–15:00 CET**, which closes at the pit open and places stops there — the same anchor. 43006 differs in range length and fixed $0.40/$0.90 vs $0.70/$1.60 stops |
| 43007 | XAU rolling 48-bar H1 S/R channel | `QM5_12914`, `QM5_10229`, `QM5_1635` | Donchian channel breakout on XAU; also inside the falsified static-S/R-on-gold class of §1–2 |

Additionally **43006's `XBRUSD.DWX` leg is not buildable**: XBRUSD has no row in
`framework/registry/dwx_symbol_matrix.csv` (it is retired — its stale magic-registry rows were the
blocker cleared on 2026-08-15). Every other symbol named across the drop resolves:
XAUUSD, EURUSD, GBPUSD, USDJPY, EURJPY, GBPJPY, USDCAD, SP500, NDX, WS30, GDAXI, XTIUSD.

Symbol normalisation would have been, per the Century precedent: US500→SP500, NAS100→NDX,
US30→WS30, GER40→GDAXI, WTI/CL→XTIUSD.

## 4. What is worth keeping — three parameter variants, routed to incumbents

Rejecting the cards does not mean rejecting everything in them. Three variants are concrete, cheap,
and not currently in the incumbent's sweep. They belong in the incumbent's setfile grid, where they
cost a backtest each, rather than as new EA ids, where they would cost a magic number and a full
Q02–Q10 chain apiece:

1. **`QM5_11153` (qc-orb30):** add a **15-minute** opening range alongside the 30-minute one. Same
   basket, same code path, one input.
2. **`QM5_10958` (ftmo-ib-brk):** add an **ADX(14) > 25** ignition gate on the FX legs as an
   optional filter, and the `EURJPY/GBPJPY` legs the drop names.
3. **`QM5_10354` (et-crude-orb):** add a **30-minute** range variant ending at the pit open, against
   its current 60-minute ranges.

These are proposals, not applied changes — no setfile, registry, or reservoir state was touched by
this triage.

## 5. Why nothing was minted

Minting 20 ids would have added 20 magic-registry rows and 20 Q02–Q10 chains for mechanics the
factory already holds, and re-tested two lines it closed with artefacts. The reservoir stands at
**3,279 approved cards** with a dense ORB/breakout population; its constraint is not card supply.
Under the standing programme the binding constraint is **orthogonality over addition**
— and this drop is addition of the least orthogonal kind: three vendor systems that are themselves
session-anchored S/R breakouts, two of them already falsified here on the exact symbol they target.

## 6. Evidence

- source document: `C:\Users\Administrator\Desktop\Strategy_Cards_Overview_2.md`
- reservoir: `D:\QM\strategy_farm\artifacts\cards_approved` (3,279 cards, deduped by body grep)
- Gold Reaper: `docs/research/GOLD_REAPER_BREAKOUT_MINING_2026-07-23.md` (`d52584351` → `30c0ee5fd`)
- Balke: `docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27.md`; `D:/QM/reports/balke_walkforward/result.json`
- symbols: `framework/registry/dwx_symbol_matrix.csv`
- precedent: `decisions/2026-08-15_century_suite_intake_triage.md` (82/16/2)
