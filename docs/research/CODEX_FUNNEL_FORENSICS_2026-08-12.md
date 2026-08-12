# Independent Q05-Q10 Funnel Forensics — 2026-08-12

## Decision

`Q08 = 19` is **correct for the dashboard's implemented metric**: lifetime distinct
`(ea_id, symbol)` pairs with at least one Q08 `PASS`. It is not a raw-row count and it
is not the population of one current-regime funnel. There are 27 Q08 `PASS` rows, which
deduplicate to 19 pairs [SQL-1].

The apparent growth from Q08 `19` to Q09 `34` and Q10 `34` is therefore not evidence
that 15 sleeves bypassed Q08. It is a semantics/provenance artifact:

1. The chips are independent lifetime PASS sets, cumulative across gate-regime eras;
   the dashboard says explicitly that adjacent chips are not one regime's funnel
   (`C:/QM/repo/tools/strategy_farm/render_cockpit.py:2529-2534`; rendered values at
   `D:/QM/strategy_farm/dashboards/cockpit.html:747-753`).
2. Q09 `34` is the union of `Q09_PORTFOLIO/PASS_PORTFOLIO`,
   `Q09_NEWS/CONFIG_LOCKED`, and legacy `Q09/PASS`, not the count that has passed both
   current Q09 arms (`C:/QM/repo/tools/strategy_farm/render_cockpit.py:2464-2480`).
   The backup contains 34 union-success pairs but only 1 pair with both current success
   labels [SQL-3].
3. Q10 also has 34 lifetime PASS pairs, but only 17 overlap the displayed Q09-success
   set; each side has 17 pairs absent from the other [SQL-3]. The equal chip values are
   coincidental, not a 100% conversion.
4. All 41 Q10 rows in the snapshot predate or bypass the present paired-dependency
   representation: zero has both `Q09_NEWS` and `Q09_PORTFOLIO` dependency roles
   [SQL-7]. Current code leaves historical Q10 visible but refuses to execute it without
   both authenticated arms (`C:/QM/repo/tools/strategy_farm/farmctl.py:5922-5929`), and
   creates new Q10 only after `CONFIG_LOCKED` can be paired with `PASS_PORTFOLIO`
   (`C:/QM/repo/tools/strategy_farm/farmctl.py:15200-15218`).

The operational conclusion is: **do not repair the Q08 chip**. Add a current-contract
cohort view (or relabel the existing row as lifetime evidence), and show paired Q09/Q10
qualification separately from legacy-visible passes.

## Scope and method

All bulk SQL was run against this immutable URI, never the live farm database:

`file:D:/QM/strategy_farm/state/backups/farm_state_before_xti_cohort_block_20260812T164553Z.sqlite?mode=ro&immutable=1`

The unit throughout is a distinct `(ea_id, symbol)` sleeve. Definitions:

- **Reached**: at least one row exists at the phase.
- **Ever verdict**: the pair has ever recorded that verdict. These columns overlap when
  retries or recalibrations produced multiple rows.
- **Exclusive disposition**: deterministic evidence precedence `PASS > FAIL_HARD >
  FAIL > DD park > FAIL_SOFT > INFRA_ONLY > OPEN_ONLY`; this makes each reached pair
  appear exactly once [SQL-2]. It is an audit disposition, not a claim that an old PASS
  supersedes every later operational concern.
- **Adjacent cohort**: start with the upstream phase's distinct PASS set and classify
  only that same set at the next phase [SQL-4 and SQL-5]. This is the only defensible
  way to discuss conversion or queue starvation.

The requested vault files under `G:/My Drive/.../03 Pipeline/` could not be read because
the headless scheduled-task session did not expose a `G:` filesystem drive. I therefore
used the canonical executable phase implementations as operational truth and record
the documentation drift below. No sibling Codex report, survivor-program report, or
Claude workflow output was used.

## What the dashboard actually counts

The requested `tools/strategy_farm/dashboards/render_dashboards.py` builds a raw
`phase_matrix`: it loads every work-item row and increments row counters, recognizing
only exact `PASS`, `FAIL`, and `INVALID`; other verdicts go to `other`
(`tools/strategy_farm/dashboards/render_dashboards.py:858-887` and
`:903-932`). That routine does **not** generate the `255 / 179 / 19 / 34 / 34` progress
chips.

Those chips come from canonical `render_cockpit.py`:

- `_pass_pairs` counts `COUNT(DISTINCT ea_id || '|' || symbol)` with exact `PASS`
  (`C:/QM/repo/tools/strategy_farm/render_cockpit.py:2325-2331`).
- Q02-Q10 chips use that distinct-pair function over canonical and declared legacy
  aliases (`C:/QM/repo/tools/strategy_farm/render_cockpit.py:2455-2468`).
- Q09 is overridden by the union-style special verdict query
  (`C:/QM/repo/tools/strategy_farm/render_cockpit.py:2469-2480`).
- Its own footnote calls the counts cumulative across gate-regime eras
  (`C:/QM/repo/tools/strategy_farm/render_cockpit.py:2529-2534`).

Thus the rendered Q05 `283`, Q06 `255`, Q07 `179`, Q08 `19`, Q09 `34`, and Q10 `34`
are reproduced exactly by the backup and the canonical query model [SQL-1 and SQL-3;
rendered row at `D:/QM/strategy_farm/dashboards/cockpit.html:747`].

## Gate semantics used in this audit

| Phase | Executable contract and disposition semantics | Primary source |
|---|---|---|
| Q05 | PF above 1.0, drawdown no more than 25%, and at least 20 trades. A drawdown breach parks as `FAIL_DD_PORTFOLIO_REVIEW`; it does not cascade to Q06 and is not an automatic retirement. | `C:/QM/repo/framework/scripts/q05_stress_medium.py:51-53`, `:574-595` |
| Q06 | Deterministic 10% trade rejection under HARSH settings; PF above 1.0, drawdown no more than 25%, and at least 20 trades. | `C:/QM/repo/framework/scripts/q06_stress_harsh.py:1-12`, `:194-205` |
| Q07 | Five seeds (`42, 17, 99, 7, 2026`) over full history under Q06 HARSH. Any seed PF below 1.0 fails; variance below 20% passes. The current second axis also passes variance in `[20%, 40%)` when worst-seed PF is at least 1.10; variance at least 40% still fails. | `C:/QM/repo/framework/scripts/q07_multiseed.py:1-10`, `:45-58`, `:615-663` |
| Q08 | The implementation runs 11 Davey sub-gates, including 8.11 MC shuffled drawdown. `FAIL_HARD` is a definitive merit failure; tooling/non-computable states route to infra; `FAIL_SOFT` routes to the portfolio track. | `C:/QM/repo/framework/scripts/q08_davey/__init__.py:1-20`; `aggregate.py:1448-1464`, `:1577-1616`, `:1635-1647` |
| Q09/Q10 | Current Q10 requires an authenticated `Q09_NEWS/CONFIG_LOCKED` parent and a matching `Q09_PORTFOLIO/PASS_PORTFOLIO` parent, including evidence hashes and common Q08 lineage. | `C:/QM/repo/tools/strategy_farm/farmctl.py:13206-13307`, `:15200-15218` |

There is a small prose drift worth fixing separately: `phase_ids.py` still describes Q08
as 10 sub-gates (`C:/QM/repo/tools/strategy_farm/phase_ids.py:21-24`), while the
executable module defines and lists 11 (`C:/QM/repo/framework/scripts/q08_davey/__init__.py:1-16`).

## True lifetime evidence counts

The first table deliberately keeps retry overlap visible.

| Phase | Rows | Reached pairs | Ever success | Ever merit failure / park | Ever infra | Ever open | Evidence |
|---|---:|---:|---:|---:|---:|---:|---|
| Q05 | 1,006 | 599 | PASS 283 | FAIL 283; DD park 27 | 73 | 0 | SQL-1 |
| Q06 | 467 | 289 | PASS 255 | FAIL 41 | 23 | 1 | SQL-1 |
| Q07 | 390 | 255 | PASS 179 | FAIL 51 | 52 | 1 | SQL-1 |
| Q08 | 577 | 192 | PASS 19 | HARD 105; SOFT 80 | 40 | 1 | SQL-1 |
| Q09_NEWS | 86 | 33 | CONFIG_LOCKED 1 | REVIEW_REQUIRED 18; INVALID_EVIDENCE 1 | 16 | PENDING_RUNNER 16 pairs; pending 3 pairs | SQL-3 |
| Q09_PORTFOLIO | 117 | 101 | PASS_PORTFOLIO 34 | FAIL_PORTFOLIO 64; NEED_MORE_DATA 10 | — | — | SQL-3 |
| Q10 | 41 | 35 | PASS 34 | FAIL 1 | 0 | 0 | SQL-1 |

The overlap is material. For example, Q08 has 105 pairs that ever recorded
`FAIL_HARD`, 80 that ever recorded `FAIL_SOFT`, and 40 that ever recorded
`INFRA_FAIL`, but only 192 reached pairs total because reruns put some pairs in more
than one set [SQL-1].

Applying the stated evidence precedence produces an additive view:

| Phase | PASS | Terminal merit | Nonterminal soft/park | Infra-only | Total reached | Evidence |
|---|---:|---:|---:|---:|---:|---|
| Q05 | 283 | FAIL 258 | DD portfolio review 20 | 38 | 599 | SQL-2 |
| Q06 | 255 | FAIL 25 | — | 9 | 289 | SQL-2 |
| Q07 | 179 | FAIL 35 | — | 41 | 255 | SQL-2 |
| Q08 | 19 | FAIL_HARD 102 | FAIL_SOFT 62 | 9 | 192 | SQL-2 |
| Q10 | 34 | FAIL 1 | — | 0 | 35 | SQL-2 |

## Real adjacent-cohort attrition

| Upstream PASS cohort | Next-phase result | Pair count | Queue interpretation | Evidence |
|---|---|---:|---|---|
| Q05 PASS (283) | Q06 PASS / FAIL / INFRA_ONLY / NO_ROW | 248 / 24 / 9 / 2 | Only the 2 NO_ROW pairs are direct snapshot-lag candidates. | SQL-4 |
| Q06 PASS (255) | Q07 PASS / FAIL / INFRA_ONLY / NO_ROW | 179 / 35 / 41 / 0 | No queue starvation: every pair reached Q07. | SQL-4 |
| Q07 PASS (179) | Q08 PASS / FAIL_HARD / FAIL_SOFT / INFRA_ONLY / NO_ROW | 18 / 96 / 57 / 8 / 0 | No queue starvation: every pair reached Q08. | SQL-4 |
| Q08 PASS (19), portfolio arm | PASS_PORTFOLIO / FAIL_PORTFOLIO / NEED_MORE_DATA / NO_ROW | 5 / 12 / 2 / 0 | Every pair reached the arm; most were rejected on portfolio contribution or data sufficiency. | SQL-5 |
| Q08 PASS (19), news arm | CONFIG_LOCKED / REVIEW_REQUIRED / PENDING_RUNNER / OPEN_ONLY / NO_ROW | 1 / 3 / 12 / 3 / 0 | Every pair has a news row, but only one has the success label needed by current Q10. | SQL-5 |

For the cleanest large cohort—255 Q06 PASS pairs—the end-of-Q08 disposition is:

- 18 Q08 PASS;
- 35 Q07 merit failures plus 96 Q08 hard failures = 131 terminal merit kills;
- 57 Q08 soft failures = nonterminal portfolio-track dispositions;
- 41 Q07 infra-only plus 8 Q08 infra-only = 49 retry/repair dispositions.

Those counts sum to 255 [SQL-4; arithmetic `18 + 35 + 96 + 57 + 41 + 8`]. Among
the 237 pairs that did not obtain Q08 PASS, 55.3% are terminal merit (`131/237`),
24.1% are soft portfolio-track (`57/237`), and 20.7% are infra/retry (`49/237`)
[SQL-4; displayed arithmetic]. Therefore the large Q06-to-Q08 contraction is mostly
real robustness selection, with a substantial but minority retry debt; it is not a
missing-enqueue problem.

The earlier Q05-to-Q06 boundary is also not the dominant problem. Of the 35 Q05 PASS
pairs without a Q06 PASS, 24 have a Q06 merit FAIL, 9 are infra-only, and 2 have no Q06
row [SQL-4]. The latter is the only direct adjacent-gate queue-lag signal in Q05-Q08 at
this snapshot.

## Q07 failure forensics

Within the 255-pair Q06 PASS cohort, the 35 exclusive Q07 merit failures break down as
follows [SQL-6]:

| Latest selected Q07 FAIL reason | Pairs | Interpretation | Example |
|---|---:|---|---|
| `per_seed_pf_below_floor` | 21 | At least one randomized fill-sequence seed lost money. | `QM5_10123/XNGUSD.DWX`; three seeds below PF 1.0 at `D:/QM/reports/work_items/750f5b8a-6948-4a84-a002-ca2281701427/QM5_10123/Q07/XNGUSD_DWX/aggregate.json:143-153` |
| variance reason without current second-axis marker | 11 | Historical verdict string from an earlier Q07 rule era; still a recorded merit FAIL. | `QM5_10026/SP500.DWX` [SQL-6] |
| variance 20%-40%, current second axis not met | 2 | Dispersion breached 20% and worst-seed PF did not reach 1.10. | `QM5_1567/USDJPY.DWX`, variance 23.24% and min PF 1.060 at `D:/QM/reports/work_items/5b6eb483-3852-456f-884d-cf289bc28abe/QM5_1567/Q07/USDJPY_DWX/aggregate.json:143-153` |
| per-seed trade floor | 1 | One or more seeds had fewer than 20 trades. | `QM5_11125/SP500.DWX` [SQL-6] |

The 41 Q07 infra-only pairs are separately classified as 23 `ACTIVE_TIMEOUT`, 11
invalid seed-evidence cases, 4 missing-summary cases, and 3 rows with no stored
`verdict_reason` [SQL-6]. These are not evidence that the strategy failed Q07. For
example, `QM5_10148/EURNZD.DWX` has all five seed summaries marked invalid rather than
a losing-seed result
(`D:/QM/reports/work_items/718ec695-07e0-40f3-aa16-172f85dce6fe/QM5_10148/Q07/EURNZD_DWX/aggregate.json:39-148`).

The split also exposes rule-era mixing: current Q07 explicitly records the second-axis
decision (`C:/QM/repo/framework/scripts/q07_multiseed.py:645-663`), while 11 stored
variance failures lack that marker [SQL-6]. A current-regime recertification view should
not silently treat those historical outcomes as if they were emitted by today's code.

## Q08 failure forensics

The 179-pair Q07 PASS cohort has 96 exclusive `FAIL_HARD`, 57 exclusive `FAIL_SOFT`,
8 infra-only, and 18 PASS at Q08 [SQL-4]. This is a real statistical-selection wall,
but its buckets must not be collapsed:

- `FAIL_HARD` is terminal merit evidence. The aggregator makes hard evidence dominate
  infra/soft signals (`C:/QM/repo/framework/scripts/q08_davey/aggregate.py:1584-1589`).
  `QM5_10116/XAUUSD.DWX`, for example, records hard DSR, PBO, edge-decay, portfolio-net-PF,
  and cost-cushion classifications
  (`D:/QM/reports/work_items/cf9ced4b-76aa-4d3e-a380-8b8e50d60c6f/QM5_10116/Q08/XAUUSD_DWX/aggregate.json:5-19`),
  including non-positive Sharpe evidence at line 59. `QM5_10269/SP500.DWX` also has a
  hard runs-test concentration result (79.4% of profit in the top 20% of months)
  (`D:/QM/reports/work_items/2f69970b-739c-4694-a47c-90a5c2eda0f4/QM5_10269/Q08/SP500_DWX/aggregate.json:6-20`, `:199`).
- `FAIL_SOFT` is **not terminal**. The current aggregator sends classifications outside
  the clean-PASS allowance to the Q09 portfolio track
  (`C:/QM/repo/framework/scripts/q08_davey/aggregate.py:1635-1647`).
  `QM5_10114/SP500.DWX` is a concrete soft case: seasonal, chopping-block, and
  regime/crisis classifications are soft, with losing-month and zero-low-regime-trade
  details
  (`D:/QM/reports/work_items/5f4d38c6-9641-487f-ac3a-9db0463ec280/QM5_10114/Q08/SP500_DWX/aggregate.json:5-16`, `:78`, `:194`).
- `INFRA_ONLY` is retry/repair debt, not a robustness kill. Current code routes
  degenerate neighborhood evidence to `INFRA_RECYCLE` and tooling non-computation to
  `INFRA_FAIL` (`C:/QM/repo/framework/scripts/q08_davey/aggregate.py:1591-1616`). Some
  repairs are substantive rather than blind reruns: `QM5_10771/GDAXI.DWX` records an
  empty-strategy-parameter lineage defect in Q08.5
  (`D:/QM/reports/work_items/ebc4839c-0d95-4fb9-9881-f4b89401ca5d/QM5_10771/Q08/GDAXI_DWX/aggregate.json:132`).

## Why Q09 and Q10 cannot be read as the tail of this funnel

The lifetime Q09 store has 101 reached pairs in its union, 34 displayed success pairs,
and only 1 pair that has both current-arm success labels [SQL-3]. The current dependency
resolver requires much more than the union chip: matching EA, symbol, setfile, Q08
dependency, readable evidence, and authenticated hashes for both parents
(`C:/QM/repo/tools/strategy_farm/farmctl.py:13206-13307`).

Q10's 34 PASS pairs overlap only 16 of the 19 Q08 PASS pairs and only 17 of the 34 Q09
display-success pairs [SQL-3]. The Q08/Q10 sets therefore have 3 Q08-only and 18
Q10-only pairs; the Q09/Q10 sets have 17 on each side [SQL-3]. This is direct set
evidence that the chips are independent lifetime populations.

The row provenance confirms why. Among 41 Q10 rows, 23 have no promotion source, 12
say `pump_cascade` from Q08, and 6 say `farmctl_enqueue_backtest_ea` from Q08; none has
both current Q09 dependency roles [SQL-7]. Present code explicitly calls such rows
historical and visible-only unless the paired dependency gate exists
(`C:/QM/repo/tools/strategy_farm/farmctl.py:5922-5929`).

Accordingly:

- **Q08 `19`: correct lifetime distinct-PASS display; not a bug.**
- **Q09 `34`: correct for the implemented union chip, but misleading as a completed
  Q09 gate count.** The verdict-label intersection for both arms is 1 [SQL-3].
- **Q10 `34`: correct lifetime visible PASS count, but not a current-contract-qualified
  count.** Current bound Q10 rows in this snapshot are 0 [SQL-7].

## Recommended count model

Keep the current lifetime chips only if their label says `LIFETIME DISTINCT PASS
(MIXED ERAS)`. Add an adjacent, contract-versioned cohort panel with:

1. upstream PASS cohort size;
2. next phase `NO_ROW`, `OPEN`, `INFRA/RETRY`, `SOFT/PORTFOLIO`, `HARD`, and `PASS`;
3. Q09 arms shown separately plus `BOTH AUTHENTICATED`;
4. Q10 split into `HISTORICAL VISIBLE` and `CURRENT CONTRACT BOUND`.

That model would preserve the useful historical evidence while preventing independent
sets from masquerading as a monotone conversion funnel.

## SQL evidence

Every query below was executed against the immutable URI stated in Scope and method.

### SQL-1 — lifetime pair flags for Q05-Q08 and Q10

```sql
WITH pair_flags AS (
  SELECT phase, ea_id, symbol, COUNT(*) AS row_count,
         SUM(verdict='PASS') AS pass_rows,
         MAX(verdict='PASS') AS ever_pass,
         MAX(verdict='FAIL') AS ever_fail,
         MAX(verdict='FAIL_DD_PORTFOLIO_REVIEW') AS ever_dd_park,
         MAX(verdict='FAIL_HARD') AS ever_hard,
         MAX(verdict='FAIL_SOFT') AS ever_soft,
         MAX(verdict='INFRA_FAIL') AS ever_infra,
         MAX(status IN ('pending','active') OR verdict='PENDING_RUNNER') AS ever_open
  FROM work_items
  WHERE phase IN ('Q05','Q06','Q07','Q08','Q10')
  GROUP BY phase, ea_id, symbol
)
SELECT phase, SUM(row_count) AS rows, COUNT(*) AS reached,
       SUM(pass_rows) AS pass_rows, SUM(ever_pass) AS pass,
       SUM(ever_fail) AS fail, SUM(ever_dd_park) AS dd_park,
       SUM(ever_hard) AS fail_hard, SUM(ever_soft) AS fail_soft,
       SUM(ever_infra) AS infra, SUM(ever_open) AS open
FROM pair_flags
GROUP BY phase
ORDER BY CASE phase WHEN 'Q05' THEN 5 WHEN 'Q06' THEN 6 WHEN 'Q07' THEN 7
                    WHEN 'Q08' THEN 8 ELSE 10 END;
```

Result rows (`rows / reached / pass_rows / PASS`): Q05 `1006 / 599 / 407 / 283`;
Q06 `467 / 289 / 387 / 255`; Q07 `390 / 255 / 267 / 179`; Q08
`577 / 192 / 27 / 19`; Q10 `41 / 35 / 40 / 34`.

### SQL-2 — exclusive evidence-precedence disposition

```sql
WITH pair_flags AS (
  SELECT phase, ea_id, symbol,
         MAX(verdict='PASS') p, MAX(verdict='FAIL') f,
         MAX(verdict='FAIL_DD_PORTFOLIO_REVIEW') d,
         MAX(verdict='FAIL_HARD') h, MAX(verdict='FAIL_SOFT') s,
         MAX(verdict='INFRA_FAIL') i
  FROM work_items
  WHERE phase IN ('Q05','Q06','Q07','Q08','Q10')
  GROUP BY phase, ea_id, symbol
), disposition AS (
  SELECT phase,
         CASE WHEN p THEN 'PASS'
              WHEN h THEN 'FAIL_HARD'
              WHEN f THEN 'FAIL'
              WHEN d THEN 'DD_PORTFOLIO_REVIEW'
              WHEN s THEN 'FAIL_SOFT'
              WHEN i THEN 'INFRA_ONLY'
              ELSE 'OPEN_ONLY' END AS bucket
  FROM pair_flags
)
SELECT phase, bucket, COUNT(*) AS pairs
FROM disposition
GROUP BY phase, bucket
ORDER BY phase, bucket;
```

### SQL-3 — Q09 arms, displayed union, and overlap with Q08/Q10

```sql
WITH news AS (
  SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q09_NEWS'
), portfolio AS (
  SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q09_PORTFOLIO'
), news_pass AS (
  SELECT DISTINCT ea_id,symbol FROM work_items
  WHERE phase='Q09_NEWS' AND verdict='CONFIG_LOCKED'
), portfolio_pass AS (
  SELECT DISTINCT ea_id,symbol FROM work_items
  WHERE phase='Q09_PORTFOLIO' AND verdict='PASS_PORTFOLIO'
), dashboard_q09 AS (
  SELECT * FROM portfolio_pass
  UNION SELECT * FROM news_pass
  UNION SELECT DISTINCT ea_id,symbol FROM work_items
        WHERE phase='Q09' AND verdict='PASS'
), q08_pass AS (
  SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q08' AND verdict='PASS'
), q10_pass AS (
  SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q10' AND verdict='PASS'
)
SELECT
  (SELECT COUNT(*) FROM news) AS news_reached,
  (SELECT COUNT(*) FROM portfolio) AS portfolio_reached,
  (SELECT COUNT(*) FROM (SELECT * FROM news UNION SELECT * FROM portfolio)) AS q09_reached,
  (SELECT COUNT(*) FROM news_pass) AS news_success,
  (SELECT COUNT(*) FROM portfolio_pass) AS portfolio_success,
  (SELECT COUNT(*) FROM dashboard_q09) AS displayed_q09_success,
  (SELECT COUNT(*) FROM news_pass n JOIN portfolio_pass p USING(ea_id,symbol)) AS both_labels,
  (SELECT COUNT(*) FROM q10_pass) AS q10_pass,
  (SELECT COUNT(*) FROM dashboard_q09 q JOIN q10_pass t USING(ea_id,symbol)) AS q09_q10_overlap,
  (SELECT COUNT(*) FROM q08_pass q JOIN q10_pass t USING(ea_id,symbol)) AS q08_q10_overlap,
  (SELECT COUNT(*) FROM (SELECT * FROM q08_pass EXCEPT SELECT * FROM q10_pass)) AS q08_only,
  (SELECT COUNT(*) FROM (SELECT * FROM q10_pass EXCEPT SELECT * FROM q08_pass)) AS q10_without_q08,
  (SELECT COUNT(*) FROM (SELECT * FROM dashboard_q09 EXCEPT SELECT * FROM q10_pass)) AS q09_only,
  (SELECT COUNT(*) FROM (SELECT * FROM q10_pass EXCEPT SELECT * FROM dashboard_q09)) AS q10_without_q09;
```

Result: Q09 news reached `33`, portfolio reached `101`, union reached `101`; news
success `1`, portfolio success `34`, displayed union `34`, both labels `1`; Q10 PASS
`34`; Q09/Q10 overlap `17`; Q08/Q10 overlap `16`; Q08-only `3`, Q10-without-Q08
`18`; Q09-only `17`, Q10-without-Q09 `17`.

The Q09 verdict row/pair breakdown was obtained with:

```sql
SELECT phase,status,COALESCE(verdict,'(null)') AS verdict,
       COUNT(*) AS rows,COUNT(DISTINCT ea_id||'|'||symbol) AS pairs
FROM work_items
WHERE phase IN ('Q09_NEWS','Q09_PORTFOLIO')
GROUP BY phase,status,verdict
ORDER BY phase,status,verdict;
```

### SQL-4 — adjacent Q05→Q06→Q07→Q08 cohorts

```sql
WITH t(label,next_phase,ea_id,symbol) AS (
  SELECT 'Q05 PASS -> Q06','Q06',ea_id,symbol
  FROM work_items WHERE phase='Q05' AND verdict='PASS' GROUP BY ea_id,symbol
  UNION ALL
  SELECT 'Q06 PASS -> Q07','Q07',ea_id,symbol
  FROM work_items WHERE phase='Q06' AND verdict='PASS' GROUP BY ea_id,symbol
  UNION ALL
  SELECT 'Q07 PASS -> Q08','Q08',ea_id,symbol
  FROM work_items WHERE phase='Q07' AND verdict='PASS' GROUP BY ea_id,symbol
), f AS (
  SELECT t.label,t.ea_id,t.symbol,COUNT(w.id) rows,
         MAX(w.verdict='PASS') p,MAX(w.verdict='FAIL') f,
         MAX(w.verdict='FAIL_HARD') h,MAX(w.verdict='FAIL_SOFT') s,
         MAX(w.verdict='INFRA_FAIL') i
  FROM t
  LEFT JOIN work_items w
    ON w.phase=t.next_phase AND w.ea_id=t.ea_id AND w.symbol=t.symbol
  GROUP BY t.label,t.ea_id,t.symbol
), d AS (
  SELECT label,
         CASE WHEN rows=0 THEN 'NO_ROW'
              WHEN p THEN 'PASS' WHEN h THEN 'FAIL_HARD'
              WHEN f THEN 'FAIL' WHEN s THEN 'FAIL_SOFT'
              WHEN i THEN 'INFRA_ONLY' ELSE 'OPEN_ONLY' END bucket
  FROM f
)
SELECT label,bucket,COUNT(*) AS pairs
FROM d GROUP BY label,bucket ORDER BY label,bucket;
```

### SQL-5 — both Q09 arms for the Q08 PASS cohort

```sql
WITH source AS (
  SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q08' AND verdict='PASS'
), f AS (
  SELECT arm,s.ea_id,s.symbol,COUNT(w.id) rows,
         MAX(w.verdict='CONFIG_LOCKED') locked,
         MAX(w.verdict='REVIEW_REQUIRED') review,
         MAX(w.verdict='PENDING_RUNNER') plan,
         MAX(w.verdict='PASS_PORTFOLIO') pp,
         MAX(w.verdict='FAIL_PORTFOLIO') fp,
         MAX(w.verdict='NEED_MORE_DATA') need,
         MAX(w.verdict='INFRA_FAIL') infra
  FROM source s
  CROSS JOIN (SELECT 'Q09_NEWS' arm UNION ALL SELECT 'Q09_PORTFOLIO') a
  LEFT JOIN work_items w
    ON w.phase=a.arm AND w.ea_id=s.ea_id AND w.symbol=s.symbol
  GROUP BY arm,s.ea_id,s.symbol
), d AS (
  SELECT arm,
         CASE WHEN rows=0 THEN 'NO_ROW'
              WHEN arm='Q09_NEWS' AND locked THEN 'CONFIG_LOCKED'
              WHEN arm='Q09_NEWS' AND review THEN 'REVIEW_REQUIRED'
              WHEN arm='Q09_NEWS' AND plan THEN 'PENDING_RUNNER'
              WHEN arm='Q09_NEWS' AND infra THEN 'INFRA_ONLY'
              WHEN arm='Q09_PORTFOLIO' AND pp THEN 'PASS_PORTFOLIO'
              WHEN arm='Q09_PORTFOLIO' AND fp THEN 'FAIL_PORTFOLIO'
              WHEN arm='Q09_PORTFOLIO' AND need THEN 'NEED_MORE_DATA'
              WHEN arm='Q09_PORTFOLIO' AND infra THEN 'INFRA_ONLY'
              ELSE 'OPEN_ONLY' END bucket
  FROM f
)
SELECT arm,bucket,COUNT(*) AS pairs
FROM d GROUP BY arm,bucket ORDER BY arm,bucket;
```

### SQL-6 — Q07 reason taxonomy inside the Q06 PASS cohort

```sql
WITH source AS (
  SELECT DISTINCT ea_id,symbol FROM work_items WHERE phase='Q06' AND verdict='PASS'
), flags AS (
  SELECT s.ea_id,s.symbol,
         MAX(w.verdict='PASS') p,MAX(w.verdict='FAIL') f,MAX(w.verdict='INFRA_FAIL') i
  FROM source s
  LEFT JOIN work_items w
    ON w.phase='Q07' AND w.ea_id=s.ea_id AND w.symbol=s.symbol
  GROUP BY s.ea_id,s.symbol
), wanted AS (
  SELECT ea_id,symbol,CASE WHEN f THEN 'FAIL' WHEN i THEN 'INFRA_FAIL' END chosen
  FROM flags WHERE NOT p AND (f OR i)
), ranked AS (
  SELECT x.chosen,w.ea_id,w.symbol,w.payload_json,w.evidence_path,
         ROW_NUMBER() OVER (
           PARTITION BY w.ea_id,w.symbol ORDER BY w.updated_at DESC,w.id DESC
         ) rn
  FROM wanted x
  JOIN work_items w
    ON w.phase='Q07' AND w.ea_id=x.ea_id AND w.symbol=x.symbol
   AND w.verdict=x.chosen
), reasons AS (
  SELECT chosen,ea_id,symbol,
         COALESCE(json_extract(payload_json,'$.verdict_reason'),'(missing)') reason,
         evidence_path
  FROM ranked WHERE rn=1
), normalized AS (
  SELECT *,CASE
    WHEN reason LIKE 'per_seed_pf_below_floor:%' THEN 'per_seed_pf_below_floor'
    WHEN reason LIKE 'pf_variance_pct=%second_axis_not_met%' THEN 'pf_variance_20_40_second_axis_not_met'
    WHEN reason LIKE 'pf_variance_pct=%' THEN 'pf_variance_legacy_no_second_axis_marker'
    WHEN reason LIKE 'seed_trades_below_floor:%' THEN 'seed_trades_below_floor'
    WHEN reason='ACTIVE_TIMEOUT' THEN 'ACTIVE_TIMEOUT'
    WHEN reason LIKE 'seeds_invalid_evidence:%' THEN 'seeds_invalid_evidence'
    WHEN reason LIKE 'summary_missing:%' THEN 'summary_missing'
    ELSE reason END reason_group
  FROM reasons
)
SELECT chosen,reason_group,COUNT(*) AS pairs,
       MIN(ea_id||'/'||symbol) AS example
FROM normalized
GROUP BY chosen,reason_group
ORDER BY chosen,pairs DESC,reason_group;
```

### SQL-7 — Q10 provenance and present-contract dependency binding

```sql
SELECT COUNT(*) AS q10_rows,
       SUM(verdict='PASS') AS pass_rows,
       COUNT(DISTINCT CASE WHEN verdict='PASS' THEN ea_id||'|'||symbol END) AS pass_pairs,
       SUM(json_extract(payload_json,'$.promotion_source') IS NULL) AS no_source_rows,
       SUM(json_extract(payload_json,'$.promotion_source')='pump_cascade') AS pump_rows,
       SUM(json_extract(payload_json,'$.promotion_source')='farmctl_enqueue_backtest_ea') AS enqueue_rows,
       SUM(CASE WHEN
         EXISTS (SELECT 1 FROM work_item_dependencies d
                 WHERE d.child_work_item_id=work_items.id
                   AND d.dependency_role='Q09_NEWS')
         AND EXISTS (SELECT 1 FROM work_item_dependencies d
                     WHERE d.child_work_item_id=work_items.id
                       AND d.dependency_role='Q09_PORTFOLIO')
       THEN 1 ELSE 0 END) AS both_bound_rows
FROM work_items
WHERE phase='Q10';
```

Result: `41` rows, `40` PASS rows, `34` distinct PASS pairs, provenance rows
`23 / 12 / 6` (none / pump / enqueue), and `0` rows with both current dependency roles.
