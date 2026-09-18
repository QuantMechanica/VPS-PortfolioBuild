# FTMO-deployable roster selection — full v2 chain re-run (2026-09-18)

**Role: DECISION_SUPPORT_EVIDENCE. Roster selection, book construction, install, attach and
AutoTrading remain OWNER-only (ROT). Nothing here was installed, attached or toggled.**

> **Read ADDENDUM A first.** Sections 1-8 price no overnight financing. Addendum A applies
> the FTMO financing model of `docs/ftmo/FTMO_ALT_ROSTER_SWAP_2026-09-18.md` and **changes the
> recommended roster from `D2` to `D2f`**. The deployability classification in section 1 is
> unaffected.

Trigger: `docs/ops/evidence/2026-09-18_ftmo_demo_recompose_R2/PACKAGE.md` §4 B1 — three of the
eight `R2_capped` sleeves gate all trading on an exact `_Symbol == "<X>.DWX"` string and would be
**silently dark** on FTMO venue names. `GAPS.md` G10 states the R2 first-passage numbers do not
transfer to a repaired roster. This document re-runs the whole v2 chain on rosters that are
FTMO-deployable by construction.

| | |
|---|---|
| engine | `tools/strategy_farm/ftmo/first_passage.py build`, schema `qm.ftmo-first-passage/v2` |
| parameters | seed `20260915`, 10,000 paths, block 10 bd, horizon 1008 bd, funded horizon 120 bd, 20 credible-interval batches, engine cost grid `[(1.0,0),(1.0,1),(1.0,2),(1.5,0),(1.5,2)]` |
| inputs | frozen W38 snapshot `D:\QM\reports\book_evolution\2026-W38\ftmo\snapshot_r2` (sha-verified at load) |
| harness | `holdout/holdout_lib.py` reused verbatim; driver `deployable/run_deployable_chain.py`, aggregator `deployable/compare_deployable.py` |
| artefacts | `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\deployable\` |
| reproduction check | `full/demo_8` reproduces the published `E2E 0.6993 / LCB 0.6571 / p50 746 bd` exactly (`FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` §3) |

---

## 1. Deployability classification of all 24 measured W38 streams

Method: direct source read of each EA's `.mq5` at `C:\QM\repo` HEAD (no git), plus the framework
resolver and the live FTMO-Demo per-EA logs. Machine-readable:
`deployable/deployability.json`, raw scan `deployable/symbol_literal_scan.json`.

Three classes:

* **A — deployable.** Symbol comes from the chart, or from an `input` compared through
  `QM_MagicSymbolCanonical` (bare-name tolerant). Nothing gates on a literal.
* **B — NOT deployable without a source repair.** An exact `.DWX` literal gates trading logic.
  The EA inits cleanly and never trades. **Silent** — no error, no log line. A repair rebuilds the
  `.ex5`, which is a new identity and re-enters at Q02.
* **C — deployable only after a registry alias add.** No literal, but the venue base name is not
  canonicalised, so `QM_MagicChecked`'s registry-symbol guard fails **closed** at init. **Loud**
  (`FRAMEWORK_INIT_FAILED` / `magic_resolution_failed`), so it cannot be mistaken for a live sleeve.

Resolver evidence: `framework/include/QM/QM_MagicResolver.mqh:133-141` (canonicalisation, strips at
the first `.`, single alias `USOIL → XTIUSD`), `:213-231` (fail-closed registry-symbol guard),
`framework/include/QM/QM_Common.mqh:273-280` (`QM_MagicChecked(ea_id, slot, _Symbol)` at init),
`framework/templates/EA_Skeleton.mq5:147-168` (`INIT_OK` is emitted **only after**
`QM_FrameworkInit` returned true — so an `INIT_OK` on a venue name is proof the guard passed).

### 1.1 Class A — 14 sleeves

| key | venue | drift USD/bd | source evidence | live evidence on the FTMO demo |
|---|---|--:|---|---|
| `13213:USDJPY.DWX` | `USDJPY` | 14.968 | `QM5_13213_balke-gmt3-range-breakout.mq5:256-263` returns false; zero literals | — |
| `10706:GBPUSD.DWX` | `GBPUSD` | 10.063 | `QM5_10706_tv-mon-ls.mq5:106-109` returns false; zero literals | `QM5_10706_ea-10706.log` INIT_OK ×15 / TM_OPEN ×6 / ENTRY_ACCEPTED ×6 |
| `10700:XAUUSD.DWX` | `XAUUSD` | 9.044 | `QM5_10700_tv-liq-break.mq5:294-307` TF+spread only | `QM5_10700_ea-10700.log` INIT_OK ×22 / TM_OPEN ×1 / ENTRY_ACCEPTED ×1 |
| `11422:USDCAD.DWX` | `USDCAD` | 2.799 | `QM5_11422_williams-…-d1.mq5:90-96` TF only | `QM5_11422_ea-11422.log` INIT_OK ×5 / TM_OPEN ×2 / ENTRY_ACCEPTED ×2 |
| `10145:XAUUSD.DWX` | `XAUUSD` | 2.711 | `QM5_10145_tsm-meanret.mq5:88-93` TF only | — |
| `10403:XAUUSD.DWX` | `XAUUSD` | 2.070 | `QM5_10403_et-turtle20x.mq5:252-263` weekday+spread only | — |
| `21505:XAGUSD.DWX` | `XAGUSD` | 1.204 | `QM5_21505_…mq5:85` canonical compare against the `strategy_host_symbol` input | `QM5_21505_ea-21505.log` INIT_OK ×5, no entries (scarcity, not a gate) |
| `41219:XAUUSD.DWX` | `XAUUSD` | 0.900 | `QM5_41219_…mq5:53-66` TF+spread only | — |
| `13054:XTIUSD.DWX` | `USOIL.cash` | 0.738 | `QM5_13054_brent-tom-mom.mq5:62` canonical compare | `QM5_13054_ea-13054.log` INIT_OK ×5 **on `USOIL.cash`** |
| `1537:XAGUSD.DWX` | `XAGUSD` | 0.717 | `QM5_1537_aa-vol-sma10.mq5:79-82` + `:165-170` — host name comes from the `strategy_calendar_symbol` **input** | `QM5_1537_ea-1537.log` INIT_OK ×6 / TM_OPEN ×2 / ENTRY_ACCEPTED ×2 |
| `11421:EURUSD.DWX` | `EURUSD` | 0.657 | `QM5_11421_…mq5:305-320` spread only | `QM5_11421_ea-11421.log` INIT_OK ×9 / TM_OPEN ×4 / ENTRY_ACCEPTED ×4 |
| `10513:XAUUSD.DWX` | `XAUUSD` | 0.573 | `QM5_10513_mql5-ichimoku.mq5:170-190` spread+session only | — |
| `11708:EURUSD.DWX` | `EURUSD` | 0.417 | `QM5_11708_…mq5:59-62` returns false | — |
| `11910:NZDUSD.DWX` | `NZDUSD` | 0.402 | `QM5_11910_…mq5:72-75` returns false | log file is **empty** |

Two class-A sleeves carry a **preset** obligation, not a code one:

* `1537` — `strategy_calendar_symbol` must be set to `"XAGUSD.DWX"` on the FTMO venue
  (documented in-source at `:57-61`). Left empty, `QM1537_HostSymbol()` returns `_Symbol`
  (`"XAGUSD"`), `Strategy_HostRegistrationMatches()` (`:165-170`) fails against the basket row
  `"XAGUSD.DWX"`, and the sleeve is **silently dark** — a class-B failure mode reachable through a
  preset. Its live `ENTRY_ACCEPTED ×2` shows the currently installed preset does set it.
* `21505` / `13054` — the `.DWX` `input` default is safe **because** the comparison is canonical.

### 1.2 Class B — 8 sleeves (not deployable without a source repair)

| key | gate | NoTradeFilter |
|---|---|---|
| `11660:NDX.DWX` | `QM5_11660_pp-wedge.mq5:74-78` — `Strategy_ExpectedSlot()` returns `-1` unless `_Symbol` is one of five `.DWX` literals | `:200-203` |
| `21507:XAUUSD.DWX` | `QM5_21507_qs-kama-trend-xau.mq5:156` `_Symbol != "XAUUSD.DWX"`; `:246` would also force-close a position whose symbol is not the literal | `:154-157` |
| `20266:XTIUSD.DWX` | `QM5_20266_collins-66mom.mq5:69` `Strategy_IsXtiD1()` | `:252-255` |
| `12710:XTIUSD.DWX` | `QM5_12710_commodity-tsmom-12m-atr.mq5:56` | `:150-153` |
| `12849:XTIUSD.DWX` | `QM5_12849_brent-tsmom12m.mq5:53` `Strategy_IsBrentD1()` | `:147-150` |
| `11881:GBPUSD.DWX` | `QM5_11881_connors-rsi2-mean-reversion.mq5:69-87` — slot table of `.DWX` literals, `_Symbol == expected` | `:216-219` |
| `12855:XTIUSD.DWX` | `QM5_12855_brent-nov-fade.mq5:51` | `:117-120` |
| `20048:XTIUSD.DWX` | `QM5_20048_wti-preholiday.mq5:145` `_Symbol!="XTIUSD.DWX"` | `:143-147` |

**Delta to PACKAGE.md B1 (new finding).** B1 names three sleeves because it scanned only the eight
`R2_capped` members. Across the full 24-stream universe the class-B population is **8**, not 3. The
additions are `21507`, `11881`, `12849`, `12855`, `20048`. Two of them sit in published rosters:
**`21507` is a member of `R1_docC` and of `R4_ratio`**, and **`12855` is a member of `R1_docC`**.
`R1_docC` therefore carries **three** dark sleeves (`11660`, `21507`, `12855`) and `R4_ratio`
carries two (`11660`, `21507`) — neither is deployable either.

`20048` is the class-B failure mode observed live: `INIT_OK ×5 / TM_OPEN ×0 / ENTRY_ACCEPTED ×0`
on `USOIL.cash` since 2026-09-11.

### 1.3 Class C — 2 sleeves (one registry alias each)

| key | venue | blocker |
|---|---|---|
| `13013:NDX.DWX` | `US100.cash` | zero literals (`QM5_13013_grimes-trendday-v2.mq5:329-345` is TF/parameter gating only). Blocked **only** because `QM_MagicSymbolCanonical` has no `NDX → US100` alias |
| `9641:WS30.DWX` | `US30.cash` | zero literals (`QM5_9641_…mq5:94-97`). Needs `WS30 → US30` |

`11660` is **B+C**: it needs both the source repair *and* the alias.

### 1.4 Correction to GAPS.md G11 — `13054` is not dark for a code or preset reason

`GAPS.md` G11 reads `13054`'s `TM_OPEN = 0` as "dark for the preset reason", i.e. the
DXZ-derived preset leaves `strategy_host_symbol` at `XTIUSD.DWX`. The source does not support that:
`QM5_13054_brent-tom-mom.mq5:62` compares **canonically**, and
`canonical("USOIL.cash") = "USOIL" → "XTIUSD" = canonical("XTIUSD.DWX")`. Independently, the live
log shows `INIT_OK ×5` on `USOIL.cash`, which per `EA_Skeleton.mq5:147-168` can only be emitted
after `QM_MagicChecked(13054, 0, "USOIL.cash")` returned a magic — so the **installed binary**
carries the `USOIL` alias and the same canonical function the strategy gate uses. The un-excluded
explanation for `TM_OPEN = 0` is signal scarcity (154 active days over ~8 years ≈ 19 entry-days a
year; zero in a one-week observation is unremarkable). This does **not** change G11's finding about
`20048`, which is genuinely dark.

---

## 2. Compositions

Universe: the 24 measured streams (`stream_stats.json`, `status = OK`), duplicates
`21501:USDJPY.DWX` and `41221:EURUSD.DWX` excluded by the snapshot's duplicate policy. Ranking
basis: own-span drift USD/bd at 0.3125 % risk — the same basis `R2_capped` used.

| roster | rule | sleeves | weights | book risk |
|---|---|---|---|---|
| `demo_8` | control — current demo roster | 8 | 0.3125 % each | 2.5000 % |
| `R2_capped_13213half` | reference — the B1-blocked R2 roster with 13213 halved | 8 (3 class-B inside) | 0.3125 %, 13213 0.15625 % | 2.34375 % |
| **D1** | `R2_capped` minus the class-B sleeves | 5 | 0.3125 % each | 1.5625 % |
| **D1r** | D1 rescaled to the D2 book with 13213 halved | 5 | 0.520833 %, 13213 0.260417 % | 2.34375 % |
| **D2** | top-8 by drift restricted to class A; caps reported as warnings only | 8 | 0.3125 %, 13213 0.15625 % | 2.34375 % |
| **D2c** | same class-A universe with symbol ≤2 / family ≤3 **applied** as the R2 rule does | 8 | 0.3125 %, 13213 0.15625 % | 2.34375 % |
| **D3** | D2 sleeve set at uniform risk | 8 | 0.25 % each | 2.0000 % |

```
D1   13213 USDJPY · 10706 GBPUSD · 10700 XAUUSD · 11422 USDCAD · 10145 XAUUSD
D2   D1 + 10403 XAUUSD · 21505 XAGUSD · 41219 XAUUSD          [XAUUSD ×4 — cap warning]
D2c  D1 + 21505 XAGUSD · 13054 USOIL.cash · 1537 XAGUSD       [no cap warning]
```

**Class A vs class A+C makes no difference to D2.** The top-8 of the A-only ranking and of the
A+C ranking are the *same eight keys*: the two class-C sleeves rank 9th (`13013`, drift 0.821) and
14th (`9641`, drift 0.568), below `41219` (0.900). Both variants are reported in
`roster_definitions_deployable.json` (`D2_identical_with_C: true`). **No alias add is needed for
any recommended roster** — the `NDX → US100` / `WS30 → US30` question is therefore not on the
critical path, which is the cheapest possible answer to `GAPS.md` G7.

---

## 3. Results

Four panels. Two are the windows the task asked for; two are window-confound controls, because the
engine's window is the intersection of a roster's **own** sleeve spans, so rosters are otherwise
compared over different regimes (the same confound `FTMO_ALT_ROSTER_CHAIN_2026-09-18.md` §4 records).

* **full** — untruncated frozen snapshot.
* **fullcommon** — every stream truncated to `2019-01-22 .. 2024-12-06`, the span common to the
  union of all roster sleeves.
* **dtest** — 2023-01-01 .. end (the holdout window).
* **dtestcommon** — `2023-07-31 .. 2024-12-06`, the common span inside the holdout window.

`P(daily-loss breach)` is **0.0000 in every stage of every roster in every panel and every cost
scenario** — Max Loss is the only binding rule, as in every prior run.

### 3.1 Full sample

| roster | risk % | LCB | E2E | p10/**p50**/p90 bd | P(maxloss) P1 | dominant breach sleeve | cost ×1.5+2 E2E | USD-ENB | max abs r | caps | class |
|---|--:|--:|--:|---|--:|---|--:|--:|--:|---|---|
| `demo_8` | 2.500 | 0.6571 | 0.6993 | 392/**746**/1205 | 0.0244 | 10706 GBPUSD 46.7 % | 0.6438 | 3.42 | 0.147 | none | 6A+2B |
| `R2_capped_13213half` | 2.344 | 0.9293 | 0.9531 | 186/**344**/627 | 0.0086 | 10700 XAUUSD 24.4 % | 0.9293 | 5.42 | 0.087 | none | **5A+3B** |
| `D1` | 1.562 | 0.8800 | 0.9057 | 184/**360**/684 | 0.0288 | 13213 USDJPY 59.0 % | 0.8425 | 3.63 | 0.071 | none | 5A |
| `D1r` | 2.344 | 0.8280 | 0.8570 | 127/**259**/506 | 0.0608 | 10700 XAUUSD 34.5 % | 0.8008 | 3.88 | 0.071 | none | 5A |
| **`D2`** | 2.344 | **0.9419** | 0.9549 | 214/**389**/690 | 0.0066 | 10700 XAUUSD 28.8 % | **0.9312** | 4.83 | 0.557 | XAUUSD ×4 | **8A** |
| `D2c` | 2.344 | 0.9057 | 0.9178 | 240/**461**/846 | 0.0148 | 10706 GBPUSD 26.4 % | 0.8648 | 4.80 | 0.294 | none | **8A** |
| `D3` | 2.000 | 0.9317 | 0.9421 | 223/**408**/724 | 0.0101 | 13213 USDJPY 56.4 % | 0.8998 | 4.41 | 0.557 | XAUUSD ×4 | **8A** |

### 3.2 Full sample, common window `2019-01-22 .. 2024-12-06`

| roster | risk % | LCB | E2E | p10/**p50**/p90 bd | P(maxloss) P1 | dominant breach sleeve | cost ×1.5+2 E2E | USD-ENB | max abs r |
|---|--:|--:|--:|---|--:|---|--:|--:|--:|
| `demo_8` | 2.500 | 0.7620 | 0.7908 | 349/**668**/1123 | 0.0121 | 10706 GBPUSD 43.8 % | 0.7440 | 3.45 | 0.172 |
| `R2_capped_13213half` | 2.344 | 0.9194 | 0.9356 | 198/**377**/705 | 0.0129 | 11660 NDX 30.2 % | 0.8969 | 5.34 | 0.085 |
| `D1` | 1.562 | 0.8137 | 0.8340 | 193/**389**/768 | 0.0588 | 13213 USDJPY 59.4 % | 0.7352 | 3.58 | 0.082 |
| `D1r` | 2.344 | 0.7779 | 0.8021 | 131/**271**/536 | 0.0873 | 10700 XAUUSD 32.8 % | 0.7341 | 3.85 | 0.082 |
| **`D2`** | 2.344 | **0.9379** | 0.9524 | 214/**395**/722 | 0.0080 | 10700 XAUUSD 25.0 % | **0.9261** | 4.84 | 0.560 |
| `D2c` | 2.344 | 0.9318 | 0.9462 | 215/**403**/737 | 0.0074 | 10700 XAUUSD 31.1 % | 0.9182 | 4.80 | 0.330 |
| `D3` | 2.000 | 0.9279 | 0.9425 | 223/**410**/754 | 0.0099 | 13213 USDJPY 54.6 % | 0.8954 | 4.43 | 0.560 |

### 3.3 Holdout 2023+ (`2023-01-01 .. end`)

| roster | risk % | LCB | E2E | p10/**p50**/p90 bd | P(maxloss) P1 | dominant breach sleeve | cost ×1.5+2 E2E | USD-ENB | max abs r | window bd |
|---|--:|--:|--:|---|--:|---|--:|--:|--:|--:|
| `demo_8` | 2.500 | 0.4480 | 0.4972 | 416/**828**/1305 | 0.0505 | 10706 GBPUSD 50.7 % | 0.4214 | 3.57 | 0.246 | 355 |
| `R2_capped_13213half` | 2.344 | 0.9840 | 0.9907 | 152/**256**/434 | 0.0006 | 10706 GBPUSD 50.0 % | 0.9875 | 5.45 | 0.101 | 746 |
| `D1` | 1.562 | 0.9600 | 0.9712 | 158/**285**/511 | 0.0043 | 13213 USDJPY 46.5 % | 0.9527 | 3.58 | 0.103 | 759 |
| `D1r` | 2.344 | 0.9536 | 0.9639 | 109/**201**/365 | 0.0097 | 10700 XAUUSD 35.1 % | 0.9488 | 3.80 | 0.103 | 759 |
| **`D2`** | 2.344 | **0.9860** | 0.9936 | 184/**294**/474 | **0.0000** | *none — no P1 breach recorded* | **0.9909** | 5.04 | 0.577 | 615 |
| `D2c` | 2.344 | 0.9578 | 0.9647 | 223/**408**/718 | 0.0015 | 10700 XAUUSD 40.0 % | 0.9445 | 5.27 | 0.439 | 405 |
| `D3` | 2.000 | 0.9840 | 0.9902 | 193/**315**/521 | 0.0002 | 13213 USDJPY 100 % | 0.9846 | 4.56 | 0.577 | 615 |

### 3.4 Holdout, common window `2023-07-31 .. 2024-12-06`

| roster | risk % | LCB | E2E | p10/**p50**/p90 bd | P(maxloss) P1 | dominant breach sleeve | cost ×1.5+2 E2E | USD-ENB | max abs r |
|---|--:|--:|--:|---|--:|---|--:|--:|--:|
| `demo_8` | 2.500 | 0.2475 | 0.2851 | 408/**834**/1335 | 0.1573 | 10706 GBPUSD 55.9 % | 0.2288 | 3.57 | 0.102 |
| `R2_capped_13213half` | 2.344 | 0.9698 | 0.9796 | 167/**299**/519 | 0.0009 | 11660 NDX 44.4 % | 0.9710 | 5.74 | 0.318 |
| `D1` | 1.562 | 0.9076 | 0.9228 | 181/**356**/686 | 0.0177 | 13213 USDJPY 52.0 % | 0.8602 | 3.72 | 0.131 |
| `D1r` | 2.344 | 0.8917 | 0.9070 | 128/**262**/513 | 0.0312 | 10706 GBPUSD 31.7 % | 0.8584 | 4.04 | 0.131 |
| **`D2`** | 2.344 | **0.9659** | 0.9810 | 200/**352**/601 | 0.0006 | 10706 GBPUSD 50.0 % | **0.9713** | 5.07 | 0.583 |
| `D2c` | 2.344 | 0.9460 | 0.9665 | 212/**385**/680 | 0.0024 | 10706 GBPUSD 41.7 % | 0.9487 | 5.12 | 0.494 |
| `D3` | 2.000 | 0.9558 | 0.9696 | 211/**378**/664 | 0.0020 | 10706 GBPUSD 40.0 % | 0.9447 | 4.63 | 0.583 |

### 3.5 Falsification rule

*An alternative must beat `demo_8` on **both** `P_FIRST_NET_FTMO_PAYOUT_LCB` and end-to-end median
at ≤ 2.5 % book risk* (`FTMO_PORTFOLIO_GAP_CURRENT.md` §5 action 1). **Every D-roster passes on all
four panels.** `demo_8` is the only failing row, by construction.

---

## 4. Reading

1. **The deployability repair is not a cost — it is an improvement.** `D2` (all class A) beats the
   B1-blocked `R2_capped_13213half` on LCB in three of four panels (full 0.9419 vs 0.9293;
   fullcommon 0.9379 vs 0.9194; dtest 0.9860 vs 0.9840) and loses only on the short
   `dtestcommon` panel (0.9659 vs 0.9698). The three dark sleeves were not carrying the reference
   roster; `13213`, `10706`, `10700` were.
2. **Do not deploy D1 as the fix.** Dropping the three class-B sleeves and leaving the remaining
   five at 0.3125 % (`D1`, 1.5625 % book) is the cheapest option in `PACKAGE.md` B1 remediation
   list, and it is the **worst** deployable roster on every panel — LCB 0.8800 / 0.8137 / 0.9600 /
   0.9076. Rescaling it back up to the same book risk (`D1r`) makes it strictly worse still
   (0.8280 / 0.7779 / 0.9536 / 0.8917) because a 5-sleeve book concentrates: `P(maxloss)` rises to
   0.0608 full / 0.0873 fullcommon, the worst figures in the study. **Sleeve count, not book risk,
   is what the first-passage engine is rewarding here.**
3. **`D2`'s cap warning is real and should be weighed, not waved through.** `XAUUSD ×4` comes with
   a measured `10145 ~ 10403` correlation of **0.557 / 0.583**, which is exactly the economic
   dependence the advisory cap exists to surface (`OWNER-DEC-D3-20260915`: measure real economic
   dependence, not labels). It did not stop `D2` from winning — unlike `R4_ratio`, which stacked
   four XAU streams *and* included the now-known class-B `21507` — but the concentration is the
   single most fragile thing about `D2`.
4. **`D2c` is the price of removing that warning: ~0.6 to ~2.0 LCB points.** On the long common
   window the two are near-identical (0.9318 vs 0.9379). On the holdout panels `D2c` is clearly
   behind (0.9578 vs 0.9860; 0.9460 vs 0.9659), and part of that gap is a window artefact —
   `D2c` contains `1537`, whose stream ends 2024-12-06, so its own `dtest` window is 405 bd against
   `D2`'s 615 bd.
5. **`D3` buys risk headroom almost for free.** Same eight sleeves, uniform 0.25 %, 2.0 % book:
   LCB within 0.004-0.010 of `D2` on three panels, `P(maxloss)` lower on the full panels, median
   19 bd slower. If OWNER wants the extra breach margin, `D3` is where it comes from — not `D1`.
6. **USD-ENB confirms the §3 finding of the chain doc.** Every 8-sleeve deployable roster sits at
   4.4-5.3 effective bets, against `demo_8`'s 3.42-3.57, and the 5-sleeve rosters at 3.6-4.0.
   `demo_8`'s nominal 8 sleeves are worth fewer effective bets than `D3`'s 8 at a lower book risk.
7. **`demo_8` degrades badly out of sample.** LCB 0.6571 full → 0.4480 dtest → 0.2475 dtestcommon,
   with `P(maxloss) P1` rising to 0.1573 and `10706 GBPUSD` carrying 50-56 % of the breaches. This
   is the same sleeve the chain doc flagged as carrying a 1,137 USD daily σ against 41-394 USD for
   the rest. And per §1.2, two of `demo_8`'s eight sleeves (`20048`, plus `13054` only if its
   preset were wrong) are class-B/preset-dark, so the realised demo statistics describe a smaller
   book than the ledger reports — `GAPS.md` G11, reconfirmed.

---

## 5. Verdict

**Best FTMO-deployable roster (no financing; SUPERSEDED by Addendum A, which recommends `D2f`): `D2` — top-8 by measured drift restricted to class A, 13213 at half
risk, 2.34375 % book.**

```
13213 USDJPY  0.15625 %      10145 XAUUSD  0.3125 %
10706 GBPUSD  0.3125  %      10403 XAUUSD  0.3125 %
10700 XAUUSD  0.3125  %      21505 XAGUSD  0.3125 %
11422 USDCAD  0.3125  %      41219 XAUUSD  0.3125 %
```

It beats `demo_8` on both axes on **all four** panels, including both out-of-sample ones
(LCB 0.9860 vs 0.4480 and median 294 vs 828 bd on `dtest`; 0.9659 vs 0.2475 and 352 vs 834 bd on
the common holdout window), it has the best cost-stressed E2E of any roster in the study
(0.9909 / 0.9713 on the holdout panels), and it beats the blocked reference roster it replaces.

### 5.1 Code and registry changes it needs

**None.** All eight sleeves are class A: no `.mq5` edit, no recompile, no new EA identity, no Q02
re-entry, and no `QM_MagicSymbolCanonical` alias. That is the whole point of the selection rule.

What it still needs — all of it already on the books as deployment tooling, none of it roster-specific:

| item | source | class |
|---|---|---|
| governor allow-list (`allowed_magics_csv` / `governed_ea_ids_csv` / `governed_symbols_csv`) rewritten for the new roster **and** the pinned `governor.active_preset_sha256` in `tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json` updated in the same change | `PACKAGE.md` B2, `GAPS.md` G3 | repo change, blocking |
| `demo_install.py` generalised off the 2026-09-06 constants | `PACKAGE.md` B3, `GAPS.md` G1 | repo change, blocking |
| `trial_setpath` v2/v3 + Swing/Standard rulepack reconciliation | `GAPS.md` G2 | repo change, blocking-adjacent |
| magic registry: `10403` slot for `XAUUSD.DWX` is slot 2 (`104030002`), `41219` slot 0, `21505` slot 0, `10145` slot 34 — all `status=active`; re-verify `magic = ea_id*10000 + slot` per sleeve before install | `framework/registry/magic_numbers.csv` | verification |
| `USDCAD` alias-registry row, and the `FTMO_TRIAL` venue being bound to account `1513845506` rather than `1514536732` | `GAPS.md` G5/G6 | hygiene, pre-existing |
| fresh `.set` derivation for the five sleeves not in the R2 package (`10403`, `21505`, `41219`, and re-derivation for `10145`, `10700`) | — | build step |

### 5.2 If OWNER prefers no concentration warning

**`D2c`** — same rule with symbol ≤2 / family ≤3 applied — replaces `10403`, `41219` with
`13054 USOIL.cash` and `1537 XAGUSD`, clears the `XAUUSD ×4` warning and drops max `|r|` from 0.56
to 0.29 (full). Cost: LCB 0.9057 / 0.9318 / 0.9578 / 0.9460 — still beating `demo_8` on both axes
on all four panels. It is also **class A only, so likewise needs no code change**, but it inherits
two preset obligations: `1537` requires `strategy_calendar_symbol = "XAGUSD.DWX"` (§1.1) and
`13054` requires a binary carrying the `USOIL` alias (its live `INIT_OK ×5` shows the installed one
does).

### 5.3 If OWNER prefers more breach margin

**`D3`** — `D2`'s sleeve set at uniform 0.25 %, 2.0 % book. Costs 0.4-1.0 LCB points and ~19 bd of
median, buys ~0.5 pp of `P(maxloss)` on the full panels and half a point of book risk.

**Not recommended: `D1` / `D1r`.** They are the literal reading of `PACKAGE.md` B1 remediation
option 1 and they are the weakest deployable rosters in the study (§4.2).

**Not deployable at all, and should be marked as such:** `R2_capped` (3 dark sleeves),
`R1_docC` (**3** dark sleeves — `11660`, `21507`, `12855`), `R4_ratio` (2 dark sleeves —
`11660`, `21507`).

---

## 6. Assumptions

1. The frozen W38 snapshot streams are the measured truth for each (EA, symbol) pair; the engine
   re-verifies every sha256 at load, and the truncated copies carry the sha of the truncated file.
2. Truncation keeps a trade only if it is **fully contained** in the window (close-day inside AND
   entry-day not before the start), in the rulepack timezone — `holdout_lib.py` docstring.
3. Drift ranking uses each stream's **own span**, which is what `R2_capped` used. A common-span
   ranking would order the universe differently; not re-derived here.
4. `13213` at half risk is carried over from the `R2_capped_13213half` reference (`holdout/step_e`)
   and is *not* re-optimised here. It remains the dominant breach sleeve in several panels at half
   risk, so a smaller weight may be better; untested.
5. Book risk ≤ 2.5 % is treated as the constraint; 2.34375 % is chosen so `D1r`, `D2`, `D2c` and
   `R2_capped_13213half` are compared at **identical** book risk.
6. Advisory caps are warnings, never filters, except inside the *definition* of `D2c`, where the
   caps are the stated selection rule (same construction `R2_capped` used).
7. USD-ENB is `recompose/metrics.effective_number_of_bets` on **actual USD** daily P/L with the
   **actual** risk weights. It is not comparable to the 7.52 in
   `D:\QM\reports\book_evolution\2026-W38\ftmo\evidence.md`, which is reproducible only on
   volatility-normalised sleeves (chain doc §3).
8. Spread is zero on `.DWX`; expectancies are commission-inclusive and spread-free; ×1.5 + 2 USD/lot
   is the only cost stress. Swap is modelled as 0.00 in most snapshot streams — a documented
   artefact that biases D1-heavy rosters more than `demo_8`.
9. Intraday equity is the engine's per-trade-MAE proxy; the book low sums all sleeve lows as if
   every sleeve troughed simultaneously (conservative).
10. `ftmo_symbol` and `magic` in the experiment manifests are report-only placeholders; the engine
    computes exclusively from the `.DWX` stream.

## 7. Unverifiable / not closed

1. **Build provenance per `.ex5`.** The task forbids git, so it is not established that each
   canonical binary was compiled from the source read here. `GAPS.md` G8 records that all eight R2
   binaries predate 2026-09-06. Binary-level confirmation exists only where the live demo provides
   it: `10706`, `11421`, `11422`, `10700`, `1537` (trading) and `21505`, `13054`, `20048` (init).
   **Five of `D2`'s eight sleeves have no binary-level FTMO evidence at all** (`13213`, `10145`,
   `10403`, `41219`, and `21505` beyond init).
2. Whether the installed `1537` preset sets `strategy_calendar_symbol` — inferred from
   `ENTRY_ACCEPTED ×2`, not read from the installed `.set`.
3. Whether `13054`'s `TM_OPEN = 0` is scarcity or something else. `INIT_OK ×5` rules out the
   resolver guard; nothing rules in a fired signal.
4. FTMO venue tradability was **not** re-probed here for `XAUUSD`, `XAGUSD`, `USDJPY`, `USDCAD`
   beyond what `PACKAGE.md` §1.2 records (`XAUUSD`, `USDJPY`, `USDCAD`, `GBPUSD`, `US100.cash`,
   `USOIL.cash` verified). **`XAGUSD` is not in that table** and is required by `D2` (`21505`) and
   by `D2c` (`21505`, `1537`) — its live `INIT_OK`/`ENTRY_ACCEPTED` on the demo is the only
   evidence, and the alias registry is scoped to the wrong account (`GAPS.md` G5).
5. Whether the Q08 gate evidence behind the class-A sleeves is uniformly `PASS`. The two
   `FAIL_SOFT` rows `GAPS.md` G9 names (`11660`, `12710`) are both class B and drop out of every
   recommended roster, but the Q08 verdicts of `10403`, `41219`, `21505`, `13054`, `1537`,
   `10145` were **not** re-checked in this run.
6. The `dtestcommon` window is 334 business days. Conclusions drawn from it are thin.
7. Residual regime confound: even on the "common" panels the engine re-intersects per roster, so
   window lengths still differ by up to 7 bd (`fullcommon`: 1273-1508 bd).

---

## 8. Files

All under `D:\QM\reports\book_evolution\2026-W38\ftmo\fable_alt_rosters_20260918\deployable\`.

| file | what |
|---|---|
| `classify_deployability.py` | read-only symbol-literal scanner over the 24 EA sources |
| `symbol_literal_scan.json` | its output — every literal with file, line, kind and text |
| `deployability.json` | the A/B/C classification with per-sleeve `file:line` citations and live evidence |
| `run_deployable_chain.py` | driver — builds the rosters and runs 28 engine invocations |
| `roster_definitions_deployable.json` | roster compositions, weights, cap panels, A vs A+C equivalence |
| `manifest_{full,dtest,fullcommon,dtestcommon}.json` | `qm.recompose-frozen-inputs/v1` manifests the engine resolved |
| `streams_{dall,dtest,fullcommon,dtestcommon}/` + `*_index.json` | truncated stream sets and their sha/span records |
| `{panel}_{roster}.json` + `_manifest.json` | 28 engine outputs |
| `results_deployable.json` | KPI contract values for all 28 runs |
| `compare_deployable.py`, `comparison_deployable.json` | aggregation, USD-ENB, dependence panel, falsification flags |

---

# ADDENDUM A — overnight financing applied (2026-09-18)

Added after §1-§8 were written, on the evidence of
`docs/ftmo/FTMO_ALT_ROSTER_SWAP_2026-09-18.md` and
`…/fable_alt_rosters_20260918/swap/`. **It changes the verdict of §5: the recommended
roster becomes `D2f`, not `D2`.** §1-§8 stand as written; every number there is a
*no-financing* number, and the swap study's `nofin` control shows that pipeline
reproduces the published figures exactly.

Method: `swap/financing_lib.py` reused verbatim — primary rate table, the charged-night
rule verified against realised fills, `net ← net + financing`,
`mae_acct ← mae + min(financing, 0)`, and the same **finance-then-truncate** ordering
`swap/run_chain.py` used. Engine parameters unchanged (seed 20260915, 10,000 paths,
block 10, horizon 1008/120, 20 batches, same cost grid). Drivers:
`deployable/run_financing_addendum.py`, `deployable/run_finaware_arm.py`; aggregation
`deployable/compare_financing.py` → `comparison_financing.json`.

## A.1 Per-sleeve financing across the full class-A universe

Full sample, source risk, primary rates. The swap study's §2.1 table covers only the R2
sleeves; this extends it to every sleeve any deployable roster uses.

| sleeve | trades | overnight % | median hold h | financing USD | gross net USD | **financing / gross** |
|---|--:|--:|--:|--:|--:|--:|
| `13213` USDJPY | 1 596 | **0.0** | 7.2 | 0 | 102 838 | **0.0 %** |
| `13054` USOIL.cash | 82 | 87.8 | 72.0 | −366 | 4 831 | −7.6 % |
| `10706` GBPUSD | 360 | 45.3 | 7.7 | −6 404 | 69 102 | −9.3 % |
| `11422` USDCAD | 195 | 79.5 | 41.0 | −3 678 | 18 310 | −20.1 % |
| `11910` NZDUSD | 63 | 84.1 | 116.9 | −569 | 2 425 | −23.5 % |
| `11421` EURUSD | 91 | 73.6 | 24.9 | −1 394 | 4 163 | −33.5 % |
| `10700` XAUUSD | 373 | 55.5 | 19.7 | −25 574 | 61 675 | −41.5 % |
| `41219` XAUUSD | 72 | 84.7 | 48.0 | −3 462 | 5 139 | −67.4 % |
| `10403` XAUUSD | 207 | 85.0 | 75.7 | −11 090 | 13 523 | −82.0 % |
| `21505` XAGUSD | 116 | **100.0** | 116.0 | −6 201 | 7 224 | **−85.8 %** |
| `11660` NDX (class B) | 1 410 | 41.0 | 12.0 | −29 864 | 30 517 | **−97.9 %** |
| `10145` XAUUSD | 306 | 91.8 | 115.1 | −20 424 | 17 757 | **−115.0 %** |
| **`1537` XAGUSD** | 96 | 83.3 | 48.0 | −5 421 | 3 648 | **−148.6 %** |

**New finding: `1537 XAGUSD` is the worst sleeve in the universe at −148.6 %, worse than
the `10145` the critique named.** It is a member of the **incumbent** `demo_8` and of the
`D2c` / `D2cf` variants below. `21505 XAGUSD` (−85.8 %, 100 % overnight) is also in
`demo_8`, in `D2` and in `D2f`.

**Direction-of-bias reversal, stated plainly.** The swap study records (its assumption 11)
that the XAGUSD long rate −115.25 USD/lot/night has **no realised fill to cross-check** —
it is read from the native 2026-09-06 spec — and notes that this only hurt the incumbent,
so that study's conclusion was conservative. That is no longer true here: XAGUSD now sits
inside the **challengers** (`21505` in `D2`/`D2f`, `21505` + `1537` in `D2c`/`D2cf`). If the
silver rate is overstated, `D2`, `D2f`, `D2c` and `D2cf` are all pessimistic, and so is
`demo_8` — the *ordering* survives either way, but the absolute levels of the XAG-carrying
rosters are the least trustworthy numbers in this document.

## A.2 Financing-aware arms

* `11660 NDX` (−97.9 %) needs no action: it is **class B** and is already absent from every
  deployable roster.
* `10145 XAUUSD` (−115.0 %) is class A and *was* in `D1`, `D2`, `D2c`, `D3`. Three new arms
  exclude it, keeping the selection rule otherwise identical:
  * **`D2f`** = top-8 by gross drift, class A, minus `10145` → `10403` moves up and `13054`
    enters. `13213` halved, 2.34375 % book.
  * **`D2cf`** = the same with symbol ≤2 / family ≤3 applied.
  * **`D3f`** = `D2f`'s sleeve set at uniform 0.25 % = 2.0 % book.
* `D1` / `D1r` still contain `10145` and are reported unchanged — they were already the
  weakest arms and are not recommended.

```
D2f   13213 USDJPY · 10706 GBPUSD · 10700 XAUUSD · 11422 USDCAD
      10403 XAUUSD · 21505 XAGUSD · 41219 XAUUSD · 13054 USOIL.cash   [XAUUSD x3 warning]
D2cf  13213 · 10706 · 10700 · 11422 · 10403 · 21505 · 13054 · 1537 XAGUSD   [no warning]
D3f   D2f at uniform 0.25 %
```

A fourth arm, **`D4`**, asks the harder question: re-rank the whole class-A universe by
**financed** drift rather than gross, fitted on the TRAIN window (≤ 2022-12-31) so the
2023+ panel stays a genuine holdout (`deployable/finaware_selection.json`,
`run_finaware_arm.py`). It selects
`13213 · 10706 · 11422 · 13054 · 11708 EURUSD · 11910 NZDUSD · 10513 XAUUSD · 11421 EURUSD`
— the caps never bind, so `D4c` is identical to `D4`.

## A.3 Results — nofin vs fin, both windows

`fin` = primary rate table. `nofin` values for the first seven rosters are §3.1/§3.3
verbatim. Falsification rule: beat `demo_8` on **both** LCB and median at ≤ 2.5 % book
risk **with financing applied**.

### Full sample

| roster | risk % | LCB nofin → **fin** | ΔLCB | E2E fin | p50 bd nofin → fin | P(maxloss) P1 fin | cost ×1.5+2 E2E fin | USD-ENB | max abs r | caps | beats demo_8 (fin) |
|---|--:|---|--:|--:|---|--:|--:|--:|--:|---|---|
| `demo_8` | 2.500 | 0.6571 → **0.5287** | −0.1284 | 0.5614 | 746 → 815 | 0.0491 | 0.4927 | 3.43 | 0.134 | none | — |
| `R2_capped_13213half` *(3 dark)* | 2.344 | 0.9293 → **0.8259** | −0.1034 | 0.8536 | 344 → 439 | 0.0437 | 0.7809 | 5.46 | 0.079 | none | n/a — not deployable |
| `D1` | 1.562 | 0.8800 → **0.8027** | −0.0773 | 0.8314 | 360 → 410 | 0.0617 | 0.7270 | 3.63 | 0.061 | none | **yes** |
| `D1r` | 2.344 | 0.8280 → **0.7078** | −0.1202 | 0.7472 | 259 → 294 | 0.1217 | 0.6660 | 3.90 | 0.061 | none | **yes** |
| `D2` | 2.344 | 0.9419 → **0.8393** | −0.1026 | 0.8657 | 389 → 498 | 0.0277 | 0.7922 | 4.87 | 0.508 | XAUUSD ×4 | **yes** |
| `D2c` | 2.344 | 0.9057 → **0.7336** | −0.1721 | 0.7568 | 461 → 577 | 0.0623 | 0.6430 | 4.82 | 0.277 | none | **yes** |
| `D3` | 2.000 | 0.9317 → **0.8334** | −0.0983 | 0.8606 | 408 → 499 | 0.0325 | 0.7580 | 4.42 | 0.508 | XAUUSD ×4 | **yes** |
| **`D2f`** | 2.344 | 0.9397 → **0.8808** | **−0.0589** | **0.8921** | 410 → 492 | **0.0191** | **0.8302** | 4.81 | 0.114 | XAUUSD ×3 | **yes** |
| `D2cf` | 2.344 | 0.9018 → **0.7730** | −0.1288 | 0.7924 | 462 → 563 | 0.0507 | 0.6848 | 4.86 | 0.204 | none | **yes** |
| `D3f` | 2.000 | 0.9239 → **0.8648** | −0.0591 | 0.8812 | 424 → 494 | 0.0239 | 0.7902 | 4.33 | 0.114 | XAUUSD ×3 | **yes** |
| `D4` = `D4c` | 2.344 | 0.7900 → **0.7419** | −0.0481 | 0.7731 | 607 → 645 | 0.0311 | 0.6443 | 4.09 | 0.100 | none | **yes** |
| `D4` @2.0 % | 2.000 | 0.7738 → **0.7297** | −0.0441 | 0.7610 | 593 → 616 | 0.0455 | 0.5970 | 3.67 | 0.100 | none | **yes** |

### Holdout 2023+

| roster | risk % | LCB nofin → **fin** | ΔLCB | E2E fin | p50 bd nofin → fin | P(maxloss) P1 fin | cost ×1.5+2 E2E fin | USD-ENB | max abs r | window bd | beats demo_8 (fin) |
|---|--:|---|--:|--:|---|--:|--:|--:|--:|--:|---|
| `demo_8` | 2.500 | 0.4480 → **0.3239** | −0.1241 | 0.3695 | 828 → 857 | 0.0923 | 0.3015 | 3.57 | 0.202 | 355 | — |
| `R2_capped_13213half` *(3 dark)* | 2.344 | 0.9840 → **0.9718** | −0.0122 | 0.9785 | 256 → 301 | 0.0020 | 0.9678 | 5.49 | 0.103 | 746 | n/a |
| `D1` | 1.562 | 0.9600 → **0.9419** | −0.0181 | 0.9520 | 285 → 314 | 0.0098 | 0.9254 | 3.57 | 0.101 | 759 | **yes** |
| `D1r` | 2.344 | 0.9536 → **0.9239** | −0.0297 | 0.9377 | 201 → 224 | 0.0212 | 0.9139 | 3.80 | 0.101 | 759 | **yes** |
| `D2` | 2.344 | 0.9860 → **0.9778** | −0.0082 | 0.9862 | 294 → 353 | 0.0003 | **0.9802** | 5.05 | 0.540 | 615 | **yes** |
| `D2c` | 2.344 | 0.9578 → **0.8877** | −0.0701 | 0.9064 | 408 → 507 | 0.0104 | 0.8426 | 5.28 | 0.420 | 405 | **yes** |
| `D3` | 2.000 | 0.9840 → **0.9720** | −0.0120 | 0.9812 | 315 → 367 | 0.0010 | 0.9682 | 4.55 | 0.540 | 615 | **yes** |
| **`D2f`** | 2.344 | 0.9839 → **0.9779** | **−0.0060** | 0.9839 | 320 → 369 | 0.0003 | 0.9746 | 4.98 | 0.180 | 615 | **yes** |
| `D2cf` | 2.344 | 0.9637 → **0.9375** | −0.0262 | 0.9470 | 383 → 455 | 0.0043 | 0.9098 | 5.26 | 0.324 | 405 | **yes** |
| `D3f` | 2.000 | 0.9800 → **0.9700** | −0.0100 | 0.9791 | 338 → 382 | 0.0008 | 0.9647 | 4.46 | 0.180 | 615 | **yes** |
| `D4` = `D4c` | 2.344 | 0.8359 → **0.7939** | −0.0420 | 0.8104 | 614 → 653 | 0.0163 | 0.6860 | 4.47 | 0.135 | 484 | **yes** |
| `D4` @2.0 % | 2.000 | 0.8497 → **0.8137** | −0.0360 | 0.8395 | 594 → 623 | 0.0141 | 0.6984 | 3.93 | 0.135 | 484 | **yes** |

**Every deployable roster passes the falsification rule with financing applied, on both
windows.** `demo_8` is the only failing row.

## A.4 Reading

1. **`D2f` is the best deployable roster once financing is priced, and on the full sample
   it is not close.** LCB 0.8808 against `D2`'s 0.8393 and `D2c`'s 0.7336; it also beats the
   *undeployable* `R2_capped_13213half` reference (0.8259). On the holdout the two are a
   dead heat (0.9779 vs 0.9778) and split the tie-breakers: `D2f` has the lower correlation
   (max |r| 0.180 vs 0.540) and the smaller haircut, `D2` the marginally better
   cost-stressed E2E (0.9802 vs 0.9746). Equal `P(maxloss)` at 0.0003.
2. **Dropping `10145` is nearly free without financing and clearly positive with it.**
   `D2 → D2f` costs 0.0022 LCB nofin on the full sample (0.9419 → 0.9397) and 0.0021 on
   the holdout, and **gains** 0.0415 LCB financed. It also removes the study's worst
   correlation pair (`10145 ~ 10403`, |r| 0.557) — max |r| falls 0.508 → 0.114 — and
   softens the advisory warning from XAUUSD ×4 to ×3.
3. **Financing hurts the concentration-clean rosters most.** The ΔLCB column is a
   carry-cost ranking: `D2f` −0.0589 and `D3f` −0.0591 are the cheapest books to hold;
   `D2c` −0.1721 is the most expensive, because the variant that satisfies the symbol cap
   does so by importing `1537 XAGUSD` (−148.6 %) and keeping `21505 XAGUSD` (−85.8 %).
   **The advisory symbol cap and the financing bill point in opposite directions here.**
   That is the sharpest trade-off in this study and it is OWNER's call, not a rule's.
4. **`D4` shows financing must be a filter, not the ranking key.** Ranking the class-A
   universe by *financed* train-window drift drops `10700 XAUUSD` — the third-largest gross
   contributor in the universe — on a train-window financed drift of −1.41 USD/bd, and
   replaces it with sleeves whose financed drift is ≈ 0 (`10513` +0.015, `11421` −0.084).
   The result is the weakest 8-sleeve deployable roster in the study (LCB 0.7419 / 0.7939)
   despite the smallest-but-one haircut. Financing is a **cost on an edge, not a substitute
   for the edge**. Excluding sleeves whose financing exceeds ~100 % of gross is the right
   correction; re-ranking on net carry over-corrects.
5. **`demo_8` is hit hardest of all.** −0.1284 full and −0.1241 holdout, to LCB 0.5287 and
   **0.3239**, with `P(maxloss) P1` reaching 0.0923. Two of its sleeves (`1537`, `21505`)
   are the two most financing-expensive in the universe, and one (`20048`) is class-B dark.

## A.5 Revised verdict

**Recommended: `D2f` — top-8 by drift, class A, excluding the financing-negative `10145`,
`13213` at half risk, 2.34375 % book.**

```
13213 USDJPY      0.15625 %      10403 XAUUSD      0.3125 %
10706 GBPUSD      0.3125  %      21505 XAGUSD      0.3125 %
10700 XAUUSD      0.3125  %      41219 XAUUSD      0.3125 %
11422 USDCAD      0.3125  %      13054 USOIL.cash  0.3125 %
```

It beats `demo_8` on both axes in all four evaluations (nofin/fin × full/holdout), carries
the smallest financing haircut of any 8-sleeve roster, has the lowest `P(maxloss)` of any
roster at 2.34 % book risk, and — like every D-roster — **needs no code change, no
recompile, no new EA identity and no `QM_MagicSymbolCanonical` alias.** The
deployment-tooling items in §5.1 (governor allow-list + pinned sha, `demo_install.py`,
`trial_setpath` v2/v3) are unchanged and still blocking; the sleeve list they must be
regenerated for changes from §5's `D2` to `D2f` — i.e. `13054 USOIL.cash` replaces
`10145 XAUUSD`.

`D2f` carries **no** preset special-case: `1537`'s `strategy_calendar_symbol` obligation
(§1.1) applies only to `D2c` / `D2cf`, and `13054`'s `.DWX` input default is safe because
the comparison is canonical (§1.4).

**Lower-risk variant: `D3f`** (same sleeves, uniform 0.25 %, 2.0 % book) — LCB 0.8648 /
0.9700 financed, a 0.016 / 0.008 LCB give-up for half a point of book risk.

**Not recommended: `D2c` / `D2cf`** — they clear the concentration warning by importing the
two most financing-expensive sleeves in the universe and lose 0.11-0.15 LCB financed.
**Not recommended: `D4`** — over-corrects (A.4.4). **Not recommended: `D1` / `D1r`** —
unchanged from §5.

## A.6 Additional assumptions and unverifiable items (beyond §6 / §7)

1. Every assumption and unverifiable item of `FTMO_ALT_ROSTER_SWAP_2026-09-18.md` §6
   carries over unchanged — in particular the un-cross-checked XAGUSD rate (its item 11),
   whose **direction of bias is reversed** in this document (A.1).
2. Only the **primary** rate set was run here. The conservative (`fincons`) set was not
   re-run for the D-rosters; on the swap study's two rosters it moved LCB by ~0.006, so the
   ordering is unlikely to change, but that is an inference, not a measurement.
3. The weekend scenario (swap study §4) was **not** re-run for the D-rosters. `D2f` has
   three sleeves at 84-100 % overnight share, so it has weekend exposure that has not been
   scenario-tested, and the funded-stage weekend cut FTMO enforces is itself unverified.
4. `D4` is fitted on financed TRAIN-window streams, so its full-sample panel contains its
   own fitting window and is in-sample. Only its 2023+ panel is a holdout.
5. `10513` and `11708` enter a candidate pool for the first time in `D4`; neither has any
   live FTMO evidence and neither appears in §1's live-evidence column.
6. `D2f` gains `13054 USOIL.cash`, whose financing depends on the derived ×10
   `.DWX → USOIL.cash` contract-ratio correction (swap study §1.4). That correction is
   load-bearing for this sleeve and is derived, not read from a spec.
7. Financing is injected at source risk and scaled linearly by the engine. This is exact
   for a linear cost and the swap study argues the scaling; it was not independently
   re-verified here.
8. The financed USD-ENB and correlation figures are computed on the financed daily P/L, so
   they are not directly comparable to the nofin figures in §3 — financing changes both the
   level and the covariance of the series.

## A.7 Additional files

| file | what |
|---|---|
| `run_financing_addendum.py` | financed re-run of the seven §3 rosters plus the three `*f` arms |
| `streams_fin_{full,dtest}/` + `*_index.json` | financed streams with per-sleeve financing diagnostics |
| `manifest_fin_{full,dtest}.json`, `manifest_nofin_*_arms.json` | engine manifests |
| `results_financing_addendum.json` | KPI values for all financed and nofin runs |
| `run_finaware_arm.py`, `finaware_selection.json`, `results_finaware.json` | the `D4` financing-aware arm and its train-window financed ranking |
| `compare_financing.py`, `comparison_financing.json` | financed aggregation: USD-ENB on financed P/L, dependence panel, falsification flags |
