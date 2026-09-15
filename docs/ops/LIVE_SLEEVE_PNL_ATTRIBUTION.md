# Live Sleeve PnL Attribution

Canonical spec for the live-money signal required by OWNER Directive 3 §33 / §43H / §44.
Deterministic, idempotent, **read-only** generator:
`tools/strategy_farm/live_sleeve_attribution.py` →
`D:/QM/reports/state/live_sleeve_attribution.json` (schema `qm.live-sleeve-attribution/v1`).

> A live trading company must eventually learn from live money (directive §33). Backtest
> evidence stays PRIMARY for selection; live realized attribution is a confirmatory signal
> that grows in weight as live history accumulates. This feed makes live money contribution
> **measurable per sleeve** (directive §46 success criterion).

## Sources (READ-ONLY — this tool never writes T_Live)

| Input | Path | Written by | Freshness (as of 2026-09-15) |
|---|---|---|---|
| Normalized deal stream | `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv` | `framework/monitor/QM_AccountMonitor.mq5` (~60 s after each new deal) | PRESENT / FRESH |
| Account snapshot | `.../journal/account_snapshot.json` | same AccountMonitor EA | PRESENT / FRESH |
| Roster (magic → sleeve) | `D:/QM/reports/state/live_deployment_pointer.json` (`binary_setfile_fingerprint.per_sleeve`) | live-deploy tooling | PRESENT |

The `.dat` binary deal files under `Bases/Darwinex-Live/trades/4000090541/` are the
proprietary raw source; **the AccountMonitor already exports a documented text CSV** from
`HistoryDeal*`, so this tool parses that CSV — it does **not** decode the binary and does
**not** attach any script to T_Live. If the CSV were absent, the tool emits
`status=EVIDENCE_MISSING` with the exact remediation (enable/repair the AccountMonitor
export) rather than guessing.

## Parsing

* CSV columns: `deal_id, position_id, time_utc, entry, deal_magic, logical_magic, symbol,
  profit, swap, commission, fee, net_actual, ..., magic, type, volume, ...`.
* `net_actual = profit + swap + commission + fee` per deal (authoritative).
* A **closed position** = a `position_id` lifecycle with at least one entry deal
  (`IN`/`INOUT`) and one exit deal (`OUT`/`OUT_BY`/`INOUT`), assigned to the day of its
  **final exit UTC**; positions whose final exit is before `--start-utc` (default the
  book's `2026-07-24` inception) are excluded.
* A position's realized money = **sum of `net_actual` over ALL its lifecycle deals**
  (entry-commission included).
* Magic resolution precedence: `logical_magic` → `deal_magic` → `magic` (first non-zero).

## Mapping (magic → ea_id / symbol / slot)

Hard-Rule magic scheme `magic = ea_id*10000 + slot`:

* `ea_id = magic // 10000`
* `slot  = magic % 10000` (the magic-embedded slot)
* `symbol`, `timeframe`, preset-slot are decoded from the deployed preset filename
  `<slot>_<SYMBOL>_<TF>_QM5_<eaid>_<slug>.set`.

Magics observed in the deal stream but **not** in the current deploy pointer are reported
under `health.unmapped_magics` (historical rows, or the deliberate T1–T10 account-mirror
lines noted in CLAUDE.md) — never silently dropped, never counted as a current sleeve.

## Formulas (per sleeve)

| Field | Definition |
|---|---|
| `realized_pnl` / `net` | `sum(net_actual)` over closed positions (realized money) |
| `gross` | `sum(profit)` over lifecycle deals (before costs) |
| `swap` | `sum(swap)` |
| `commission` | `sum(commission + fee)` (negative = cost) |
| `realized_dd` | max peak-to-trough drop (money) of the sleeve's cumulative realized-net curve |
| `contribution_to_book_return` | `realized_pnl / book_base_equity` (fraction; base = first deposit, 100 000 USD) |
| `contribution_to_book_dd` | `realized_dd / book_realized_dd` (approximate DD share; `None` if book DD = 0) |
| `trade_count` | number of closed positions |
| `since_utc` / `last_deal_utc` | first / last close in the window |
| `floating_pnl` | **EVIDENCE_MISSING per sleeve** (see below) |

Book-level totals additionally carry `account_equity / account_balance /
account_floating_pnl / account_open_positions` from the account snapshot.

### Live correlation / overlap matrix

Pairwise **Pearson correlation of daily realized-net sleeve PnL** (0 on no-close days),
over the calendar window `[first close, last close]`. Emitted only when
`n_days >= 20`; below that the matrix is `EVIDENCE_MISSING` (statistically meaningless).
Each pair also carries `overlap_days` (days both sleeves closed a trade). This is the
live analogue the §7/§8 marginal-contribution analysis needs; it complements, not
replaces, the sealed backtest correlation.

## Blend rule (how the live signal enters selection)

Backtest sealed-Q14 evidence is **PRIMARY** for selection. Live realized attribution is
**confirmatory** and becomes a weighted input only once a sleeve's live history clears the
correlation threshold (`n_days >= 20`, constant `LIVE_BLEND_MIN_DAYS` in
`frozen_snapshot.py`). Until then the freeze records
`blend_stage = BACKTEST_PRIMARY_LIVE_INSUFFICIENT`; at/after the threshold it records
`LIVE_CONFIRMATORY_ACTIVE`. **Dark sleeves (zero live closes) are treated as no-data,
never zero-return.** This blend never overrides a gate verdict (RED boundary): live money
is a portfolio-recomposition input, not a gate.

## Wiring (consumers)

1. **Portfolio recompose / frozen snapshot** —
   `portfolio/recompose/frozen_snapshot.py::_live_evidence` embeds the attribution
   summary (per-sleeve realized contribution/DD, book realized PnL/DD, correlation status,
   blend stage) in the DXZ `live_evidence` block and **freezes the file byte-for-byte** into
   `inputs/live_sleeve_attribution.json`; `load_snapshot` re-hashes it (section-70
   reproducibility). `dxz_fitness` consumes this live block as the DXZ live-evidence input.
2. **Research ROI** — `research/external_roi.py` joins sleeve `ea_id` → origin programme
   and reports realized live USD per origin in `economic_contribution` (was EVIDENCE_MISSING;
   now real money when the feed is present), plus a top-level `live_economic_contribution`
   block and `unmapped_live_eas`.
3. **Strategy lineage / wiki** — `strategy_wiki_sync.py` adds read-only per-EA fields
   `live_realized_net_usd`, `live_realized_dd_usd`, `live_trade_count`, `live_last_deal_utc`
   to every generated node. Only live-book nodes carry a numeric value (and only they
   re-render when live PnL moves); the 5000+ non-live nodes render `NOT_APPLICABLE`
   (feed present) or `EVIDENCE_MISSING` (feed absent) and never churn.
4. **15-minute read-models** — appended to
   `book_evolution_runner._default_state_builds` as `live_sleeve_attribution`, so it
   refreshes before each freeze and feeds the weekly recomposition.

## Health semantics

`health` block: `source_present`, `source_freshness` (FRESH ≤ 1 h / STALE ≤ 1 d /
VERY_STALE), `deals_parsed`, `closed_positions`, `roster_size`, `mapped_sleeves`,
`unmapped_magics`, `dark_sleeves`, and the per-sleeve floating status. `authorization`
records `t_live_write=false`, `terminal_control=false`, `autotrading_toggle=false`,
`order_action=false`.

## What is EVIDENCE_MISSING today (honest gaps)

* **Per-sleeve floating PnL.** The AccountMonitor exports only **book-level** floating
  (`account_snapshot.floating_pnl`); there is no per-open-position export, so per-sleeve
  `floating_pnl` is `EVIDENCE_MISSING`. Closing this requires an open-positions export from
  the AccountMonitor EA — an **OWNER/orchestrator action** (extend
  `framework/monitor/QM_AccountMonitor.mq5` to also write open positions; no AI seat
  attaches a script to T_Live). Book-level floating is reported in `book_totals`.
* **Internal DXZ D-Score.** D-Score is computed Darwinex-side; QM ingests nothing back
  (audit `dxz_live_book.md` finding 18). Not part of this feed.
* **Correlation matrix** is `EVIDENCE_MISSING` whenever the observed window has
  `n_days < 20`.

## First real run (2026-09-15, read-only)

`python -X utf8 tools/strategy_farm/live_sleeve_attribution.py` produced:

* status **PRESENT**; source FRESH; deals parsed **261**; closed positions **103**;
  roster **24**; mapped sleeves **24**; unmapped magics **[]**.
* **Book realized PnL −2 477.67 USD**; book realized DD **3 376.52 USD**; realized return
  **−2.4777 %** on a 100 000 base; account equity **99 376.10**, book floating **−13.28**.
* Reconciliation is exact: 24 sleeves **−938.17** + manual magic-0 **−1 539.50** = book
  **−2 477.67**. (The manual magic-0 bucket is non-sleeve activity, kept separate.)
* Correlation matrix **PRESENT** (n_days **54**, 16 sleeves scored, 120 pairs).
* Dark sleeves (zero closes, treated as no-data): `10919, 12567(×2 slots), 12778, 12969,
  12989, 13117, 13128` — includes the three known symbol-literal dark sleeves
  (12778/12969/13117) from `dxz_live_book.md` finding 6.
* By origin (research ROI join): external_source **−938.17** (22 sleeves / 102 trades);
  internal_discovery **0.0** and owner_mission **0.0** (both single dark sleeves); no
  unmapped live EAs.

## Rollback

Pure add + read-only joins. To disable: remove the `live_sleeve_attribution` entry from
`book_evolution_runner._default_state_builds` (the read-model stops refreshing;
consumers degrade to `EVIDENCE_MISSING` and keep working). The generator writes only its
own read-model file; deleting it is safe and reversible.
