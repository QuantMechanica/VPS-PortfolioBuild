# Exit-Surgery Scan v2 — Darwinex Zero book v2 roster (2026-09-13)

**Analyst:** Claude (Orchestrator)
**Tool:** `tools/strategy_farm/research/exit_surgery_scan_v2.py` (deterministic, read-only)
**Outputs:** `docs/research/exit_surgery_v2/{sleeve_summary,hold_buckets,mae_winners}.csv`, `manifest.json`

---

## Purpose

OWNER asked on 2026-09-13 whether **trade management such as trailing stops would add
value** to the proposed Darwinex Zero book v2. The house precedent, established by the
2026-07-04 Exit-Surgery scan and closed by the 2026-07-06 Tier-B MAE verdict, is narrow:

- **Tier A — time-exit amputation** (mechanical time/ceiling/expiry exits cutting trades
  whose win rate *rises* with hold time) is the **only validated exit lever**. It is a
  rebuild lever (new EA id, full Q02→Q08 cascade), not a live edit.
- **Tier B — "SL too tight"** was **REJECTED** for all three tested live sleeves
  (10715/USDJPY, 10440/NDX, 10476/USDCAD) on MAE capture evidence: winners and losers
  separate early, so widening the stop only enlarges losses.

This v2 scan re-runs that method over the 30 sleeves of the v2 analysis roster
(`roster_selected.json` key `selected_book`) to see whether any sleeve carries a fresh
Tier-A hold-gradient signal, and reports the Tier-B MAE geometry per sleeve for
completeness. **It recommends nothing beyond what the numbers show.**

> Roster note: the task brief referenced "28 sleeves"; the delivered
> `roster_selected.json` `selected_book` (roster sha
> `e61a342e7ceb17079e6b247c9bdd41fa524792c2765d2ce0456539025e6dfdcd`) contains **30**
> sleeves (12 `V2B_CANDIDATE` + 18 `INCUMBENT_LIVE_BOOK`), matching its own
> `n_sleeves_evaluated_book_under_union=30`. All 30 are scanned; none is dropped.

---

## Method (quoted verbatim)

The surgery-score method is section **"## 1. Method"** of
`docs/research/EXIT_SURGERY_SCAN_2026-07-04.md`, reproduced unchanged:

> ### Population
>
> The Q08 FAIL_SOFT pool was read from `farm_state.sqlite` (latest row per ea_id/symbol):
> 31 pairs total, excluding already-surgered / fresh v2s (10939/GBPUSD, 10940/XAUUSD,
> 12989/XAUUSD, 12990/GBPUSD, 12958/XAUUSD) leaves **26 pairs** for analysis.
>
> Live sleeves from `D:/QM/reports/state/live_book_pulse.json` were cross-referenced.
> **3 HIGH candidates are currently live:** QM5_10440/NDX, QM5_10715/USDJPY,
> QM5_10911/GDAXI.
>
> ### Data source
>
> Per-trade data was extracted from the **most-recent Q08 baseline report.htm** for each
> EA:symbol pair (selected by tester.ini `Symbol=` match + most recent mtime). Each
> report.htm Deals table row-pairs (direction=in / direction=out) to produce matched trades
> with: entry_time, exit_time, hold_h, net PnL, exit comment. Minimum 30 trades required.
>
> Exit comment classification:
> - `TIME_MGMT`: contains `qm_tm` or `time_stop` (framework time management label, covers
>   both fixed time stops and signal/MA crossover closes that the framework labels uniformly)
> - `TP` / `SL`: contains `tp ` / `sl ` prefix
> - `SIGNAL_DECAY`: explicit signal close labels
> - `OTHER`: empty or unknown (frequently the opposite-channel/reversal close in DEMA-type
>   strategies, or session-end pending expiry)
>
> ### Hold-time buckets (adaptive)
>
> Buckets adapt to the EA's average hold time:
> - Short avg (<8h): `<1h / 1-4h / 4-12h / 12-48h / >48h`
> - Medium avg (8-48h): `<2h / 2-8h / 8-24h / 1-3d / >3d`
> - Long avg (>48h): `<12h / 12-48h / 2-7d / 1-4wk / >4wk`
>
> ### Surgery signal score
>
> **HIGH:** early bucket(s) net-negative AND WR < 45% AND WR gradient early→late > 8-15 pp
> AND late buckets positive AND either: TIME_MGMT/mechanical >35% of early exits (time-based
> surgery), or SL dominance with large gradient (SL-tightness surgery).
>
> **WEAK:** gradient present but not unambiguous (mild slope, early not clearly negative).
>
> **NO_CASE:** flat or negative gradient (later holds not better — exits are not the problem;
> edge is genuinely weak or absent).
>
> **NO_DATA:** fewer than 30 trades, or fewer than 3 buckets with >=5 trades.

**Tier-B MAE check** (method: `docs/research/EXIT_SURGERY_TIER_B_MAE_VERDICT_2026-07-06.md`):
per sleeve, the **losers' median |mae_acct| is the stop anchor** (their MAE/stop median is
1.00 by construction under RISK_FIXED). We report winners' MAE/anchor **median, p75, p90**
and the **shares ≥0.5 / ≥0.7 / ≥0.9**, and flag `stop_binding=true` when **≥25 % of winners
reach ≥0.5×** the anchor. **MFE is not captured in these streams, so no giveback / trailing
analysis is possible** — the trailing-stop question OWNER asked cannot be answered from
this data, only the tighter/wider-stop and time-amputation questions can.

### Deterministic implementation notes

- Verdict thresholds pinned in code: HIGH requires gradient **> 15 pp** with early net < 0,
  early WR < 45 %, late net > 0; WEAK requires gradient **> 8 pp**; else NO_CASE. NO_DATA is
  < 30 trades **or** < 3 buckets with ≥ 5 trades.
- Streams are the **sealed Q08 JSONL trade streams** (there is no exit-reason field in them);
  exit comments come **secondarily** from the MT5 report.htm resolved read-only via
  `bundle_manifest.json` → `q08_work_item_id` → DB `evidence_path` (aggregate.json) →
  `baseline_run.baseline_report_path`. Report out-deals are aligned to stream trades by
  chronological index **only when counts match**; otherwise `exit_class_source=none` (never
  fabricated). Report lookup matches ea_id **and** symbol to avoid cross-mapping a
  multi-symbol EA's reports.

---

## Population table (30 sleeves)

`wr_*` in %, `grad` in pp, `eNet`/`maeMed` from the CSVs. `tmE` = TIME_MGMT share of early
bucket (blank where no report). `src` = exit_class_source. Full precision in
`sleeve_summary.csv`.

| ea_id | symbol | src | n | avg_hold_h | set | wr_early | wr_late | grad_pp | early_net | tmE | mae_med | share≥.5 | stop_binding | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1537 | XAGUSD | report | 96 | 56.25 | long | – | – | – | – | | 0.479 | 0.487 | true | NO_DATA |
| 1556 | XAUUSD | none | 53 | 92.88 | long | – | – | – | – | | 0.291 | 0.233 | false | NO_DATA |
| 1567 | EURUSD | none | 86 | 12.85 | medium | 22.2 | 75.0 | 52.8 | -3126.84 | | 0.288 | 0.283 | true | **HIGH** |
| 9641 | WS30 | report | 64 | 67.64 | long | – | – | – | – | | 0.433 | 0.382 | true | NO_DATA |
| 10403 | XAUUSD | report | 207 | 75.53 | long | 48.0 | 60.0 | 12.0 | 491.10 | 0.96 | 0.229 | 0.175 | false | WEAK |
| 10440 | NDX | none | 618 | 4.66 | short | 23.8 | 49.2 | 25.3 | -48830.24 | | 0.397 | 0.430 | true | **HIGH** |
| 10513 | XAUUSD | report | 68 | 56.68 | long | – | – | – | – | | 0.360 | 0.290 | true | NO_DATA |
| 10700 | XAUUSD | report | 373 | 26.42 | medium | 10.7 | 69.2 | 58.5 | -17732.30 | 0.07 | 0.297 | 0.333 | true | **HIGH** |
| 10706 | GBPUSD | report | 360 | 13.95 | medium | 11.7 | 100.0 | 88.3 | -69895.70 | 0.05 | 0.404 | 0.408 | true | **HIGH** |
| 10911 | GDAXI | none | 331 | 11.61 | medium | 29.2 | 73.8 | 44.6 | -9160.08 | | 0.332 | 0.282 | true | **HIGH** |
| 10919 | XTIUSD | none | 30 | 14.48 | medium | 75.0 | 40.0 | -35.0 | 1482.38 | | 0.497 | 0.500 | true | NO_CASE |
| 10939 | GBPUSD | none | 92 | 25.83 | medium | 41.2 | 71.4 | 30.3 | -2935.03 | | 0.310 | 0.296 | true | **HIGH** |
| 11132 | SP500 | none | 73 | 50.49 | long | – | – | – | – | | 0.200 | 0.133 | false | NO_DATA |
| 11165 | AUDCAD | none | 207 | 11.72 | medium | 71.6 | 8.3 | -63.3 | 7718.94 | | 0.299 | 0.244 | false | NO_CASE |
| 11165 | EURUSD | none | 260 | 12.66 | medium | 83.3 | 13.3 | -70.0 | 1059.08 | | 0.192 | 0.184 | false | NO_CASE |
| 11421 | AUDUSD | none | 81 | 33.26 | medium | 100.0 | 20.0 | -80.0 | 1892.56 | | 0.190 | 0.265 | true | NO_CASE |
| 11421 | EURUSD | report | 91 | 30.81 | medium | 57.1 | 33.3 | -23.8 | 248.16 | 0.57 | 0.270 | 0.241 | false | NO_CASE |
| 11708 | EURUSD | report | 173 | 25.26 | medium | 100.0 | 12.5 | -87.5 | 866.11 | 0.17 | 0.296 | 0.266 | true | NO_CASE |
| 12567 | XAUUSD | none | 73 | 63.26 | long | 71.0 | 60.0 | -11.0 | 2080.58 | | 0.287 | 0.300 | true | NO_CASE |
| 12567 | XNGUSD | none | 58 | 67.30 | long | – | – | – | – | | 0.340 | 0.355 | true | NO_DATA |
| 12778 | AUDUSD | none | 195 | 93.87 | long | – | – | – | – | | 0.365 | 0.435 | true | NO_DATA |
| 12969 | USDJPY | none | 331 | 7.90 | short | – | – | – | – | | 0.327 | 0.300 | true | NO_DATA |
| 12989 | XAUUSD | none | 51 | 23.18 | medium | 14.3 | 47.6 | 33.3 | -4495.05 | | 0.357 | 0.304 | true | **HIGH** |
| 13013 | NDX | report | 70 | 6.99 | short | 0.0 | 50.0 | 50.0 | -7135.53 | 0.92 | 0.364 | 0.310 | true | **HIGH** |
| 13054 | XTIUSD | report | 82 | 67.79 | long | – | – | – | – | | 0.285 | 0.205 | false | NO_DATA |
| 13117 | EURGBP | none | 208 | 79.54 | long | 50.0 | 54.6 | 4.6 | -817.92 | | 0.648 | 0.556 | true | NO_CASE |
| 13128 | NDX | none | 56 | 23.00 | medium | – | – | – | – | | 0.493 | 0.500 | true | NO_DATA |
| 13213 | USDJPY | report | 1596 | 7.04 | short | 9.4 | 55.6 | 46.2 | -26453.57 | 0.13 | 0.297 | 0.272 | true | **HIGH** |
| 13301 | GDAXI | none | 742 | 6.09 | short | 3.7 | 61.0 | 57.3 | -26409.94 | | 0.293 | 0.267 | true | **HIGH** |
| 21505 | XAGUSD | report | 116 | 117.34 | long | – | – | – | – | | 0.356 | 0.250 | true | NO_DATA |

---

## Verdict counts

| verdict | count |
|---|---|
| HIGH | 10 |
| WEAK | 1 |
| NO_CASE | 8 |
| NO_DATA | 11 |
| **total** | **30** |

`exit_class_source`: **report = 12** (all `V2B_CANDIDATE` sleeves; the only ones bound into
`bundle_manifest.json`), **none = 18** (`INCUMBENT_LIVE_BOOK` sleeves — no Q08 work item in
the v2b bundle, so no report.htm was resolved; their exit tiers are undetermined **from these
streams**). No sleeve is missing a stream (all 30 found in `streams_v2b` or the incumbent
root).

11 NO_DATA sleeves are all sample-starved (< 30 trades, or < 3 buckets with ≥ 5 trades),
mostly the long-hold sleeves whose trades spread too thin across the long bucket set.

---

## HIGH candidates — bucket numbers

The 10 HIGH sleeves each show early net-negative, sub-45 % WR buckets whose win rate rises
sharply with hold time (all gradients > 25 pp except none). Per-bucket rows (n / WR% / net):

**Report-backed HIGH (exit tier determinable):**

- **13013 / NDX** (short, 70 tr, grad **50 pp**): `<1h` 26 / 0.0% / -7,136 → `4-12h` 21 /
  95.2% / +10,531 → `>48h` 2 / 100% / +1,941. Early TIME_MGMT share **0.92** →
  **Tier-A-shaped** (early exits are mechanical time closes killing trades that win later).
- **13213 / USDJPY** (short, 1596 tr, grad **46 pp**): `<1h` 32 / 9.4% / -26,454 → `1-4h`
  296 / 23.6% / -182,533 → `4-12h` **1232 / 55.4% / +281,491** → `12-48h` 36 / 55.6% /
  +30,334. Early TIME_MGMT share **0.13** → early losers are **SL/other, not time** = the
  **Tier-B "SL too tight" pattern**. (This is the same sleeve family as 10715/USDJPY, whose
  Tier-B claim was rejected on MAE capture in 2026-07-06.)
- **10700 / XAUUSD** (medium, 373 tr, grad **58 pp**): `<2h` 28 / 10.7% / -17,732 → `1-3d`
  137 / 51.1% / +65,173 → `>3d` 26 / 69.2% / +19,488. Early TIME_MGMT share **0.07** →
  **Tier-B pattern** (early losers exit on SL, not time).
- **10706 / GBPUSD** (medium, 360 tr, grad **88 pp**): `<2h` 77 / 11.7% / -69,896 → `1-3d`
  **78 / 92.3% / +114,684** → `>3d` 5 / 100% / +14,055. Early TIME_MGMT share **0.05** →
  **Tier-B pattern**.

**No exit-class source (tier undetermined from these streams):**

- **1567 / EURUSD** (medium, 86 tr, grad **52.8 pp**): `<2h` 9 / 22.2% / -3,127 → `8-24h`
  34 / 61.8% / +19,760 → `1-3d` 12 / 75.0% / +9,153.
- **10440 / NDX** (short, 618 tr, grad **25.3 pp**): `<1h` 151 / 23.8% / -48,830 → `4-12h`
  146 / 50.0% / +69,874 → `12-48h` 61 / 49.2% / +28,520. *(This sleeve's Tier-B claim was
  explicitly rejected in 2026-07-06 on tick-MAE evidence.)*
- **10911 / GDAXI** (medium, 331 tr, grad **44.6 pp**): `<2h` 48 / 29.2% / -9,160 → `8-24h`
  116 / 44.0% / +18,063 → `1-3d` 42 / 73.8% / +24,375. *(Tier-A surgery precedent from
  2026-07-04.)*
- **10939 / GBPUSD** (medium, 92 tr, grad **30.3 pp**): `2-8h` 17 / 41.2% / -2,935 →
  `1-3d` 35 / 48.6% / +17,022 → `>3d` 7 / 71.4% / +2,181.
- **12989 / XAUUSD** (medium, 51 tr, grad **33.3 pp**): `<2h` 7 / 14.3% / -4,495 → `8-24h`
  12 / 58.3% / +7,145 → `>3d` 2 / 100% / +3,996.
- **13301 / GDAXI** (short, 742 tr, grad **57.3 pp**): `<1h` 27 / 3.7% / -26,410 → `1-4h`
  153 / 22.2% / -93,874 → `4-12h` **561 / 61.0% / +202,287**.

**Reading of the HIGH class:** where exit tier is determinable, only **13013/NDX** shows the
Tier-A time-amputation signature (early exits are TIME_MGMT closes). The other three
report-backed HIGH sleeves (13213, 10700, 10706) have early losers dominated by **SL/other**,
which is the tautological Tier-B pattern — losers exit early at the stop *by construction* —
the class the house **rejected** in 2026-07-06. The six no-report HIGH sleeves cannot be tier-
classified from these sealed streams; a report parse (or a fresh MAE-capture run) would be
required before any Tier-A rebuild claim.

The single **WEAK** is **10403/XAUUSD** (grad +12 pp, early net *positive*): a mild slope
that does not meet the HIGH bar.

---

## Tier-B MAE table (winners' MAE / losers-median anchor)

Full data in `mae_winners.csv`. `stop_binding=true` where ≥ 25 % of winners reach ≥ 0.5×
the anchor. Selected rows:

| ea_id | symbol | n_winners | anchor | med | p75 | p90 | ≥0.5 | ≥0.7 | ≥0.9 | stop_binding |
|---|---|---|---|---|---|---|---|---|---|---|
| 10440 | NDX | 237 | 1020.38 | 0.397 | 0.634 | 0.855 | 0.430 | 0.207 | 0.080 | true |
| 10706 | GBPUSD | 152 | 1030.02 | 0.404 | 0.684 | 0.829 | 0.408 | 0.243 | 0.033 | true |
| 10700 | XAUUSD | 159 | 996.50 | 0.297 | 0.596 | 0.802 | 0.333 | 0.182 | 0.063 | true |
| 13213 | USDJPY | 775 | 1024.72 | 0.297 | 0.520 | 0.734 | 0.272 | 0.123 | 0.025 | true |
| 13301 | GDAXI | 378 | 1002.34 | 0.293 | 0.522 | 0.689 | 0.267 | 0.085 | 0.019 | true |
| 13117 | EURGBP | 108 | 104.58 | 0.648 | 2.281 | 3.868 | 0.556 | 0.481 | 0.444 | true |
| 11165 | EURUSD | 163 | 447.12 | 0.192 | 0.397 | 0.639 | 0.184 | 0.086 | 0.055 | false |
| 11132 | SP500 | 45 | 774.24 | 0.200 | 0.347 | 0.518 | 0.133 | 0.044 | 0.022 | false |

**23 of 30 sleeves flag `stop_binding=true`.** This is materially higher adverse tolerance
than the 2026-07-06 tick-capture verdict found for 10440/10476 (winner MAE median 0.00,
share≥0.5 = 1.7 %). **The difference is a data caveat, not a new verdict — see Limitations.**

---

## Limitations (binding — read before acting)

1. **The trailing-stop question cannot be answered here.** These streams carry MAE
   (`mae_acct`) but **no MFE**. Trailing-stop / giveback value requires MFE. OWNER's
   trailing-stop question is therefore a documented **evidence GAP** for this scan, not a
   negative result.
2. **The Tier-B anchor is only a stop proxy for SL-exit sleeves.** The method sets the stop
   anchor = losers' median |mae_acct| "1.00 by construction under RISK_FIXED" — which holds
   only when losers **exit at the stop**. Several sleeves here (e.g. 1537/XAGUSD, 100 %
   `qm_tm` exits) are **time-exit** EAs whose losers are time-stopped, not SL-stopped, so
   their loser |mae_acct| is **not** the stop distance and `stop_binding` is **not
   interpretable** for them. Treat `stop_binding=true` as "winners routinely draw down toward
   the loser-median adverse level," not as a proven stop-tightness case. This explains why 23
   /30 flag true here while the 2026-07-06 *tick-capture* run on SL sleeves did not — the
   anchors differ, and the sampling basis (these portfolio streams vs the 07-06 recompiled
   tick-MAE binaries) differs. Neither reconciliation is fabricated here.
3. **Exit tier is only determinable for the 12 V2B_CANDIDATE sleeves** (report-backed). The
   18 incumbents have no v2b Q08 work item, so their early-exit composition (time vs SL) is
   unknown from these streams; six of them are HIGH and cannot yet be assigned Tier A vs B.
4. **Hold-gradient HIGH is a screen, not a verdict.** Per the standing precedent, a HIGH
   gradient whose early losers are SL exits is the tautological Tier-B pattern; only Tier-A
   (early exits mechanical/time) is a validated rebuild lever, and even then only via a new
   EA id through the full Q02→Q08 cascade — never a live edit and never an auto-swap.
5. Roster count is **30**, not the 28 named in the brief (see Roster note above).

---

## Reproduce

From `C:/QM/repo` (read-only; writes only under `--out-dir`):

```
python -X utf8 tools/strategy_farm/research/exit_surgery_scan_v2.py ^
  --roster "D:/QM/reports/portfolio/dxz_v2_20260913/selective/roster_selected.json" ^
  --stream-root "D:/QM/reports/portfolio/dxz_v2_20260913/streams_v2b" ^
  --stream-root "D:/QM/reports/portfolio/dxz_final_20260719" ^
  --out-dir "docs/research/exit_surgery_v2"
```

Input file SHA-256s (30 streams + 12 reports), roster sha, and thresholds are recorded in
`docs/research/exit_surgery_v2/manifest.json`. Tests:
`python -X utf8 -m pytest tools/strategy_farm/tests/test_exit_surgery_scan_v2.py -q` (8 pass).
