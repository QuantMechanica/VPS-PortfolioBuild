# Q02 ZERO_TRADES family autopsy and build-prune advisory — 2026-08-07

## Verdict

At the router cutoff `2026-08-07T12:39:24Z`, the canonical build-ready backlog
contains exactly 434 approved, unbuilt cards. The advisory split is:

- **PRUNE: 18 cards** in three empirically silent slug-prefix families:
  `wyckoff` (5), `classical` (8), and `bressert` (5).
- **REWORK: 86 cards**: 65 selected by family/frequency or direct setup evidence,
  plus 21 additional cards selected by the mandatory-news contract overlay.
- **KEEP: 330 cards**. KEEP means only that the ZERO_TRADES record does not
  justify removing the card from the paced build backlog.

`PRUNE` here means **hold out of the next build-priming budget pending Claude
review**. It is not a card deletion, a pipeline verdict, or economic retirement.
No card, EA, queue row, terminal, or pipeline state was changed.

The machine routing artifact is
`D:/QM/reports/state/build_prune_20260807.csv` (SHA-256
`903218cbded2ac55e099afce9ae1b47d00ff74f4fe1ce7591594dfbc874f5374`).

## Scope and evidence contract

Source state:

- Database: `D:/QM/strategy_farm/state/farm_state.sqlite`, read-only snapshot at
  the router cutoff above.
- Reports: each row's bound `evidence_path` below
  `D:/QM/reports/work_items/<work_item_id>/.../summary.json`.
- Backlog: the same canonical predicates as
  `tools/strategy_farm/health.py::chk_unbuilt_cards_count`: approved card,
  R-gates ready, no canonical `.ex5`, no auto-build inbox file, and no build task
  in a pending/active/done/blocked state.
- Family key: the deterministic first token after `QM5_<id>_` in the canonical
  EA/card slug. Broad source prefixes such as `mql5`, `tv`, and `ff` are therefore
  deliberately treated as heterogeneous, not as one shared entry mechanism.

All persisted spellings of Q02 were read, but this document uses the Q-only
operator name. The cutoff contains 993 rows labelled `ZERO_TRADES` across 135
slug-prefix families. A row was accepted as terminal-valid only when its bound
summary was readable, every run was `OK` on real ticks, the model-4 marker was
present, no initialization failure occurred, the news bundle status was `OK`,
execution identity was stable when recorded, and the exact test window was
available either in the summary or its bound `tester.ini`.

- 927 of 993 rows meet that terminal-evidence contract.
- 66 are excluded from merit decisions because their bound summaries contain a
  non-OK run. Example: `fb30a1c2-57c0-48d5-ada4-3387a5ba53cb` at
  `D:/QM/reports/work_items/fb30a1c2-57c0-48d5-ada4-3387a5ba53cb/QM5_10050/20260728_052708/summary.json`.
- 611 labelled rows fall in the last 14 days, from
  `2026-07-24T12:39:24Z` through the cutoff.
- 31 labelled rows completed on 2026-08-07 before the cutoff.

The news-bundle `OK` field proves bundle availability, not that an EA enforced a
blackout. A separate logger/source check found 31 terminal-valid zero rows from
29 EAs whose logger explicitly records `NEWS_CALENDAR_SKIPPED` with
`all_news_axes_off`. They span `wti` (16), `xng` (5), `idx` (2), `wmr` (2),
`xauxag` (2), `moc` (1), `aa` (1), `xti` (1), and `oilbench` (1). These rows are
setup/contract evidence, not economic evidence. Examples are
`1646d7d1-f248-4d8f-9a42-4db7526eb2cc`,
`ab875180-bc18-48f8-85fe-c32081b2473f`, and
`3919c4ce-0843-4ad4-9110-b5a0eb278895`.

Two older high-volume sources also defaulted the effective legacy news mode to
OFF with no set-file override: QM5_1433 (30 Wyckoff rows) and QM5_1406 (2
classical rows). Those 32 rows were excluded from the PRUNE proof. The remaining
news-conforming evidence is still sufficient: 29 Wyckoff rows over 5 EAs and 11
symbols, and 26 classical rows over 3 EAs and 9 symbols.

## Decision rule

Trade frequency is annualized from the exact inclusive test-window days. The
active floor is at least 5 trades/year.

- `PRUNE`: after removing known setup/contract-invalid rows, at least three
  executed sibling EAs, at least nine symbols, a large repeated zero cohort, no
  row at or above the frequency floor, and no contrary family evidence.
- `REWORK`: a direct setup/implementation defect; explicit news-blackout breach;
  only below-floor evidence; a repeated zero cohort that is too narrow for
  PRUNE; or a mixed family whose dead/under-floor burden is large enough to
  require gate counters before another build.
- `KEEP`: above-floor sibling evidence exists, or evidence is too sparse or
  absent to infer that an unbuilt mechanic is dead. Absence is not positive
  evidence.

ZERO_TRADES is neither a pass nor an automatic rejection. Without an entry-gate
counter, “dead trigger” remains a hypothesis. No threshold, session, symbol, or
strategy mechanic was changed in this read-only task.

## High-volume full-history family inventory

This table covers every family with at least five terminal-valid ZERO_TRADES
rows. `Rows / EAs / symbols` is the raw terminal-valid cohort; contract-invalid
subsets are called out above and are not used as economics. The sample is a
concrete work-item ID, normally the most recent row at cutoff.

| Family | Rows | EAs | Symbols | Bound windows | Backlog action | Sample work item |
|---|---:|---:|---:|---|---|---|
| carver | 60 | 9 | 35 | 2018-07-02..2022-12-31 | no current backlog action | `e9bd880f-9be7-41c8-85a8-a51fb0c269e0` |
| wyckoff | 59 | 6 | 32 | 2022-07-01..2022-12-31 | PRUNE; 29 conforming rows remain | `a822a27c-aa93-4807-9a77-88c38df35e0f` |
| chande | 43 | 4 | 12 | 2022-07-01..2022-12-31 | KEEP; mixed viable siblings | `28f8095a-d1c3-4e27-b9fb-da92a5de5947` |
| qp | 41 | 7 | 35 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `4f5ad983-7fc6-4805-866a-7a95a42e2de2` |
| demark | 39 | 6 | 12 | 2022-07-01..2022-12-31 | KEEP; variant-specific zeros | `6608ffa6-c2b6-47c0-9a97-221d7944ddc3` |
| mql5 | 35 | 22 | 12 | 2018-07-02..2022-12-31 | KEEP; heterogeneous source prefix | `f15bcc97-84a4-41a7-ab14-93d0a51804f1` |
| ehlers | 34 | 4 | 17 | 2022-07-01..2022-12-31 | REWORK | `7676f13a-6bff-468a-bd92-96c365694221` |
| modified | 30 | 1 | 30 | 2022-07-01..2022-12-31 | no current backlog action | `da76f739-cc3b-4e7d-9f54-43d720936e5a` |
| nnfx | 30 | 6 | 19 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `4944ebb9-7412-4c91-b344-4e020c139e6a` |
| tv | 29 | 14 | 8 | 2018-07-02..2022-12-31 | KEEP; heterogeneous source prefix | `c3299f0d-ba43-4d56-af5e-1ba784ad8e44` |
| aa | 28 | 5 | 22 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `a95bc639-1b74-4cd6-819b-ceed77728d6e` |
| classical | 28 | 4 | 11 | 2022-07-01..2022-12-31 | PRUNE; 26 conforming rows remain | `348eaeb9-2713-4c70-aa13-6c71d34622ef` |
| ff | 26 | 2 | 25 | 2018-07-02..2022-12-31 | KEEP; heterogeneous source prefix | `e63baae0-f1ce-415c-8824-0455ebdcaad0` |
| chan_pairs_stat_arb | 25 | 1 | 25 | 2018-07-02..2022-12-31 | no current backlog action | `fb21092b-a628-4dc2-ad64-38bcd7380baa` |
| brooks | 20 | 4 | 8 | 2022-07-01..2022-12-31 | REWORK | `e0caec01-2aa5-45ea-9a2c-a29212dd8187` |
| wti | 19 | 19 | 1 | 2018-07-02..2022-12-31 | two card-level news reworks; others KEEP | `1646d7d1-f248-4d8f-9a42-4db7526eb2cc` |
| bressert | 15 | 3 | 9 | 2022-07-01..2022-12-31 | PRUNE | `21c8341a-11ff-4791-927c-207526c05eec` |
| rw | 13 | 3 | 12 | 2018-07-02..2022-12-31 | no current backlog action | `fc1edeac-8496-4c5d-854b-dfd4cc5dc946` |
| sperandeo | 13 | 1 | 13 | 2022-07-01..2022-12-31 | KEEP; viable siblings | `1ca83669-cb3d-4b89-95a4-d0878b4877ad` |
| gh | 11 | 7 | 8 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `d14c8ab9-5675-48aa-8901-666764b86e45` |
| ftmo | 10 | 7 | 5 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `88b5ac02-85de-4eab-8611-acf74eb081c7` |
| carter | 9 | 4 | 6 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `1ff65917-c8a1-45a4-850a-64e4170e3483` |
| robles | 9 | 1 | 9 | 2018-07-02..2022-12-31 | no current backlog action | `19a74dd5-7b98-423a-9f90-28d928413cf9` |
| samuels | 9 | 1 | 9 | 2018-07-02..2022-12-31 | no current backlog action | `2828e3a8-ba13-4186-9517-9ee88aab8285` |
| atc | 8 | 4 | 3 | 2018-07-02..2022-12-31 | no current backlog action | `7921fc83-bd62-4c63-a7f3-8e5fc9d9feab` |
| pring | 8 | 4 | 7 | 2018-07-02..2022-12-31 | REWORK | `f3383302-e72f-415f-8f8a-8097fb37a5d0` |
| the5ers | 8 | 3 | 6 | 2018-07-02..2022-12-31 | no current backlog action | `112ed87e-693c-4d14-abd7-bea890d0d40d` |
| xng | 8 | 8 | 2 | 2018-07-02..2022-12-31 | REWORK; five news-off rows | `ab875180-bc18-48f8-85fe-c32081b2473f` |
| connors | 7 | 4 | 5 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `11cec858-189c-47fe-b5ca-0a00615d5051` |
| qt | 7 | 3 | 3 | 2018-07-02..2022-12-31 | no current backlog action | `3c093a0d-4dd9-421f-b9c9-114fccb313b1` |
| wave59 | 7 | 1 | 7 | 2022-07-01..2022-12-31 | no current backlog action | `f9efd58b-906d-4b99-8ee5-f63a36128575` |
| larry | 6 | 1 | 6 | 2018-07-02..2022-12-31 | no current backlog action | `2846395f-47e9-473a-879d-669f2fc79049` |
| raschke | 6 | 1 | 6 | 2022-07-01..2022-12-31 | REWORK | `a7e36a22-ccad-4185-991c-d53f7e3c4aa8` |
| dahlquist | 5 | 1 | 5 | 2018-07-02..2022-12-31 | no current backlog action | `69068fe7-19ce-447d-9151-3a832c478605` |
| ft | 5 | 4 | 3 | 2018-07-02..2022-12-31 | KEEP; mixed viable siblings | `9875fac0-049b-4755-abd4-de40bfef6593` |
| hopwood | 5 | 1 | 5 | 2022-07-01..2022-12-31 | card-level news reworks; otherwise KEEP | `6ea855ab-4bd1-4fd9-99eb-68332b85093a` |
| lien_channels | 5 | 1 | 5 | 2018-07-02..2022-12-31 | no current backlog action | `2cb36381-625d-4e8b-a051-681f3d037404` |
| lt | 5 | 1 | 5 | 2018-07-02..2022-12-31 | no current backlog action | `5fca6c19-1ba0-44c0-872a-30f6aa072d85` |

The remaining 97 families contain only 202 terminal-valid zero rows in total,
one to four per family. Their shared mechanism/root cause is **NOT ESTABLISHED**
at the slug-prefix level; none is PRUNE on this sparse evidence alone:

`abo(1), adj(4), ait(1), amp(2), andrews(4), as(1), awesome(1), b3(2),
bandy(2), basing(2), bb(3), bma(1), btc(2), burke(2), caldeira(3), chan(4),
channel(4), cs(4), daylight(2), dibs(2), dorsey(4), dots(2), dtrt(2), dual(3),
dwx(2), ea31337(1), eia(1), ema(2), ema144(3), ema369(2), ema512(1), ema9(1),
emacross(2), energy(2), et(4), fin(3), fsr(3), gap(2), grimes(1), h4(2), ha(4),
harmonic(4), ht(2), iaf(1), ict(1), idx(2), jst(4), jstm(4), lien(4), liu(2),
lucca(1), ma(2), macro0830(1), moc(1), mp(3), mtf(4), mulham(1), naked(2),
narang(1), ndx(1), oil(3), oilbench(1), onr(1), orev(1), overnight(1),
paired(1), pj(1), postclose(1), psar(2), pst(3), qc(4), rainbow(2), residual(1),
risk(1), roundnum(2), rsi2(2), sb(2), shooting(1), shv(2), simplicity(3),
singh(1), sisyphus(2), sma(1), stoch(3), three(4), tmom(1), tpo(2), urquhart(1),
usdjpy(1), vbt(2), vwap2s(1), weiss(1), whc(4), wmr(2), xauxag(2), xti(3),
zuck(1)`.

## Backlog families requiring action

| Family | Cards | ZERO / EAs / symbols | Above floor / below floor rows | Mechanism and root-cause hypothesis | Verdict evidence |
|---|---:|---:|---:|---|---|
| wyckoff | 5 | 29 / 5 / 11 conforming | 0 / 0 | Multi-stage range, pivot, phase, breakout/pullback and volume conjunction. Systematic too-strict trigger is strongly supported; exact first dead gate is not established. | PRUNE: `20b3bf2e-b0ea-48bd-b885-7cabf190d8a4`, `cb124726-bb0e-4d5f-a9ee-b6c2a52c8a8d`, `a822a27c-aa93-4807-9a77-88c38df35e0f` |
| classical | 8 | 26 / 3 / 9 conforming | 0 / 1 | Multi-pivot geometry, regression/convergence and buffered breakout chains. Family remains below floor after excluding news-off QM5_1406. | PRUNE: `698d1c55-5cc0-478b-a562-f88d85680e56`, `fc1ef668-dd30-403e-9bdf-da87ca46a24e`, `75b082b1-ea85-412a-a7ca-4a7a7a8e28f3` |
| bressert | 5 | 15 / 3 / 9 | 0 / 0 | Cycle-window/IQR/recency or double-smoothed oscillator conjunction. Repeated silence across three implementations; first dead gate not instrumented. | PRUNE: `8a4a33c2-17e3-4604-81b9-775e14267550`, `24186818-0b94-4655-8571-7af4848c3991`, `21c8341a-11ff-4791-927c-207526c05eec` |
| ehlers | 25 | 34 / 4 / 17 | 9 / 39 | Mixed signal-processing variants, but zero and below-floor burden dominates. Partition by exact transform and add gate counters before building more. | REWORK: `d8d00c4a-fdec-4cee-8719-e2bdbec4ab5e`, `7676f13a-6bff-468a-bd92-96c365694221` |
| brooks | 9 | 20 / 4 / 8 | 17 / 40 | Failed-range/outside/channel pattern chains are viable in some siblings but mostly below floor. Today's 9350/9400/9504 wave is variant-specific evidence, not a whole-family death proof. | REWORK: `5e6dbfb2-85e0-4525-b115-98ac20a85691`, `ab509acb-6160-46a4-8489-2738d4bb37a9`, `e0caec01-2aa5-45ea-9a2c-a29212dd8187` |
| pring | 5 | 8 / 4 / 7 | 3 / 12 | KST/Special-K variants are mixed but predominantly below floor. Gate-level cause is not established. | REWORK: `e5f83ec0-801d-4614-afa0-39f83d91822c`, `f3383302-e72f-415f-8f8a-8097fb37a5d0` |
| ha | 2 | 4 / 1 / 4 | 0 / 0 | Direct implementation defect in QM5_20096: both pooled indicator handles remain `BarsCalculated=-1` while bars exceed 2,300 and `ntf_pass=0` through 15,000,000 calls. | REWORK: `41a774ad-2429-42de-8714-52822c225513` |
| raschke | 2 | 6 / 1 / 6 | 0 / 0 | One silent implementation across six symbols; too narrow for PRUNE. | REWORK: `a7e36a22-ccad-4185-991c-d53f7e3c4aa8` |
| harmonic | 2 | 4 / 3 / 4 | 0 / 0 | Multiple silent variants but only four rows/symbols; pattern detector cause is not instrumented. | REWORK: `6de2c122-3151-4596-86fa-f8e15e64ba6e`, `9b57123a-dc93-4a7a-8793-e6abb83d9b7a` |
| andrews | 1 | 4 / 2 / 2 | 0 / 0 | Sparse pitchfork-family silence; trigger reachability not established. | REWORK: `9a550d7e-f8a4-427b-8415-89f17d5be84d`, `bcd6a05e-89f2-46de-a47b-b71c97f62798` |
| channel | 1 | 4 / 2 / 3 | 0 / 0 | Sparse channel/reversion silence; card also explicitly disables news in Q02. | REWORK: `c711d559-455d-4f00-bfaf-3f70951baccb`; card `QM5_20071` |
| gap | 1 | 2 / 1 / 2 | 0 / 0 | Exact built sibling/card silent on two symbols; duration is six months, but breadth is insufficient for PRUNE. | REWORK: `9c05d067-12fd-42e6-8bfb-2379a942a583`, `14eead5a-b90d-4003-960d-1b6ca5a7ab23` |
| tpo | 1 | 2 / 1 / 2 | 0 / 0 | Exact built sibling/card silent on two symbols; sparse evidence. | REWORK: `27d64b67-43db-4871-a984-fcf8f2e9eda4`, `935cd5f4-4ba7-400d-820d-bf4277408ebf` |
| wmr | 1 | 2 / 1 / 2 | 0 / 0 | Both rows explicitly skipped the news calendar; setup contract fails before economics can be judged. | REWORK: `dcb03f9e-56dc-4275-9b42-68018ff41e7a`, `6f4d5f8b-02cc-4543-afb0-3b24613849f2` |
| macro0830 | 1 | 1 / 1 / 1 | 0 / 1 | One zero plus one below-floor row; session/trigger cause not established. | REWORK: `35b61e15-ea31-47f4-a7cd-a3313acb9619` |
| mulham | 2 | 1 / 1 / 1 | 0 / 1 | Only zero/below-floor evidence; insufficient breadth for PRUNE. | REWORK: `4cab1dff-0cbd-4e69-b17b-4592c66beced` |
| orev | 3 | 1 / 1 / 1 | 0 / 4 | One zero plus four below-floor rows; frequency is the problem, not proven unreachability. | REWORK: `ed0b834f-1424-41de-919a-a11470418579` |
| 4h | 1 | 0 | 0 / 4 | No zero row, but every valid family row is below the 5/year floor. | REWORK: `cad20f36-2b81-4db4-87c3-8e20d00ac0ba`, `1bf82243-510f-49cc-aaef-929337e08362` |
| audjpy | 1 | 0 | 0 / 1 | Below-floor-only evidence. | REWORK: `47fc8c32-fe57-4f98-828e-d8cb8d0f4a25` |
| colby | 2 | 0 | 0 / 3 | Below-floor-only evidence. | REWORK: `6adfc3ea-de56-45af-996f-d9fd904676cd`, `55a33e0e-b1ef-490b-ad80-932918879e51` |
| hutson | 1 | 0 | 0 / 5 | Below-floor-only evidence. | REWORK: `6d0cd273-e56c-434b-8b9a-05dee94fd0f1`, `0dfc0a4e-b852-44d5-87c9-262251557183` |
| qs | 2 | 0 | 0 / 2 | Below-floor-only evidence after exact window annualization. | REWORK: `e7c75446-1022-40d6-8990-66635c218f1c`, `10c9d265-53cc-43c6-8dec-6be9de936293` |
| xng | 1 | 8 / 8 / 2 | mixed viable siblings | Five zero rows, including today's QM5_20262, explicitly skip the required news blackout; economics are confounded. | REWORK: `ab875180-bc18-48f8-85fe-c32081b2473f` |
| moc | 1 | 1 / 1 / 1 | mixed same-EA evidence | The zero row explicitly skips news, while another row is above floor. This is a contract repair, not a dead-mechanic verdict. | REWORK: `9b198a70-0943-4482-90ee-efa583c976a9`, `6b89e46e-1862-4e86-b255-9cc81d02a858` |

### Mandatory-news card overlay

Twenty-two backlog cards explicitly say that the news filter/axes are OFF. They
are REWORK regardless of frequency evidence. The CSV records the exact card path
in `evidence_rows`; no card was edited:

`QM5_1286, QM5_1287, QM5_11291, QM5_11292, QM5_11299, QM5_11300,
QM5_11301, QM5_11302, QM5_11388, QM5_12923, QM5_12924, QM5_12925,
QM5_12926, QM5_20070, QM5_20071, QM5_20073, QM5_20074, QM5_20075,
QM5_20076, QM5_20145, QM5_20172, QM5_20186`.

QM5_20071 is already in the family REWORK set, so this overlay adds 21 rather
than 22 cards to the total. Examples tying the setup class to executed rows are
WMR `dcb03f9e-56dc-4275-9b42-68018ff41e7a`, WTI
`1646d7d1-f248-4d8f-9a42-4db7526eb2cc`, XNG
`ab875180-bc18-48f8-85fe-c32081b2473f`, and XAU/XAG
`3919c4ce-0843-4ad4-9110-b5a0eb278895`.

## Today's emphasized wave

All eleven rows named in the task are completed, real-tick, model-4 zero runs.
The first seven use six-month windows unless shown otherwise.

| EA | Work item | Symbol/window | Finding |
|---|---|---|---|
| QM5_9350 | `5e6dbfb2-85e0-4525-b115-98ac20a85691` | USDJPY, 2022-07-01..2022-12-31 | Eighth zero symbol for this EA; Brooks failed-tight-range conjunction is too strict relative to its card's ~30/year expectation. |
| QM5_9400 | `ab509acb-6160-46a4-8489-2738d4bb37a9` | USDJPY, 2022-07-01..2022-12-31 | Brooks variant-specific zero; family has some above-floor siblings, so REWORK rather than PRUNE. |
| QM5_9451 | `6608ffa6-c2b6-47c0-9a97-221d7944ddc3` | USDJPY, 2022-07-01..2022-12-31 | Eighth zero symbol for this DeMark variant; broad DeMark family remains viable, so no family prune. |
| QM5_9504 | `e0caec01-2aa5-45ea-9a2c-a29212dd8187` | USDJPY, 2022-07-01..2022-12-31 | Fifth zero symbol for this Brooks failed-channel variant; rework the exact trigger chain. |
| QM5_9507 | `e9bd880f-9be7-41c8-85a8-a51fb0c269e0` | USDJPY, 2018-07-02..2022-12-31 | Long-window Carver variant zero; the broad Carver prefix has viable siblings and no unbuilt-card overlap. |
| QM5_2080 | `f3383302-e72f-415f-8f8a-8097fb37a5d0` | USDJPY, 2022-07-01..2022-12-31 | Pring family remains predominantly below floor; REWORK. |
| QM5_20096 | `41a774ad-2429-42de-8714-52822c225513` | USDCHF, 2022-07-01..2022-12-31 | Direct implementation defect: indicator handles never become calculated; not an economic zero. |
| QM5_20097 | `348f6ba9-c743-42ad-870d-1c4f1fa963ab` | USDCHF, 2022-07-01..2022-12-31 | Fourth zero symbol for the three-timeframe SMA variant. No entry counters; dead trigger vs overly strict alignment is NOT ESTABLISHED. |
| QM5_20254 | `3919c4ce-0843-4ad4-9110-b5a0eb278895` | XAUUSD host, 2018-07-02..2022-12-31 | After warm-up, monthly memory state is repeatedly valid but flat; additionally, news axes are OFF. Setup rework precedes economic judgment. |
| QM5_20262 | `ab875180-bc18-48f8-85fe-c32081b2473f` | XNGUSD, 2018-07-02..2022-12-31 | News axes OFF; the wider XNG prefix has viable siblings. Contract/symbol-variant rework, not family death. |
| QM5_10371 | `e3583aed-5ef8-4d98-aa86-69d702474673` | GDAXI, 2022-07-01..2022-12-31 | Existing source already records a prior broker-session mapping repair; current zero leaves trigger threshold/session fit unresolved. The ET prefix has viable siblings. |

Two row-bound logger excerpts make the classification concrete:

- QM5_20096:
  `D:/QM/reports/work_items/41a774ad-2429-42de-8714-52822c225513/QM5_20096/20260807_120134/logger_sample.jsonl`
  records `h_sma=10`, `h_sto=11`, `bc_sma=-1`, `bc_sto=-1`,
  `ntf_pass=0`, and `edges=0` from one million through fifteen million filter
  calls while H4 bar count grows from 2,381 to 3,113.
- QM5_20254:
  `D:/QM/reports/work_items/3919c4ce-0843-4ad4-9110-b5a0eb278895/QM5_20254/20260807_102345/logger_sample.jsonl`
  records early `XAU_INSUFFICIENT_MONTHLY_ENDPOINTS`, then repeated
  `VALID_FLAT_MEMORY_STATE` through 2022 with variance-ratio z-scores near zero,
  plus `NEWS_CALENDAR_SKIPPED` / `all_news_axes_off`.

There were 31 total ZERO_TRADES completions today. The additional twenty are:

`QM5_12478:d14c8ab9-5675-48aa-8901-666764b86e45,
QM5_20249:c3b593c4-8d79-437a-a9c0-ed73c9ebcd51,
QM5_11810:66b67314-e885-4f67-a56b-a71650888a5d,
QM5_1424:21c8341a-11ff-4791-927c-207526c05eec,
QM5_1446:552f9c67-efc4-4ef4-a180-83e523845469,
QM5_11893:19a74dd5-7b98-423a-9f90-28d928413cf9,
QM5_1490:a7e36a22-ccad-4185-991c-d53f7e3c4aa8,
QM5_1540:21e58367-b2c4-432c-a23b-2da5c5c0fda3,
QM5_10222:6c1d064d-e04f-47d4-a3aa-d193377ebc01,
QM5_10259:c3299f0d-ba43-4d56-af5e-1ba784ad8e44,
QM5_12447:a7cff9b5-d479-4ab2-8468-21846e2683ae,
QM5_9107:a95bc639-1b74-4cd6-819b-ceed77728d6e,
QM5_1491:d8d00c4a-fdec-4cee-8719-e2bdbec4ab5e,
QM5_1493:6ea855ab-4bd1-4fd9-99eb-68332b85093a,
QM5_11103:70e46ffe-5ac3-4971-8145-6e2297252097,
QM5_20257:1646d7d1-f248-4d8f-9a42-4db7526eb2cc,
QM5_1536:3f928023-593d-430d-8604-f5b17b08764a,
QM5_9575:02ea756d-e259-4345-a4c1-e5b644c9914f,
QM5_1486:7676f13a-6bff-468a-bd92-96c365694221,
QM5_1506:d2d1cc1f-cd86-4aa6-bf65-1e1ceb323923`.

## CSV interpretation and verification

Columns are exactly:

`card_id,family,verdict(PRUNE|KEEP|REWORK),evidence_rows`

`evidence_rows` uses tagged concrete UUIDs (`ZERO`, `BELOW_FLOOR`,
`ABOVE_FLOOR`, or mixed variants). Card-level news findings add the exact
approved-card path. Where a KEEP family has no Q02 work item at all, the field is
explicitly `NO_Q02_ROWS_AT_CUTOFF`; no fake UUID is substituted. Every PRUNE and
family-level REWORK verdict cites concrete work-item IDs.

Focused verification passed:

- header exactly matches the requested four columns;
- 434 data rows and 434 unique `card_id` values;
- exact set equality with the canonical 434-card health-check cohort;
- verdict domain exactly `PRUNE`, `KEEP`, `REWORK`;
- counts exactly `18 / 330 / 86` for PRUNE / KEEP / REWORK;
- 108 deterministic slug-prefix families covered;
- CSV SHA-256
  `903218cbded2ac55e099afce9ae1b47d00ff74f4fe1ce7591594dfbc874f5374`.

## Review recommendation

Claude should first review the three PRUNE families against their exact card
mechanics, then the direct implementation/setup reworks (HA indicator lifecycle
and mandatory-news violations), then the mixed low-frequency families. A future
diagnostic run should add per-entry-gate counters before anyone claims a trigger
is mathematically unreachable. No requeue, retirement, card mutation, build, or
pipeline advancement is authorized by this artifact.
