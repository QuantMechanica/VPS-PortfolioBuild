# QM5_10025 USDJPY zero-trade recovery and Q02 handoff

Date: 2026-09-02

Branch: `agents/board-advisor`

Outcome: `COMPILE_OK; APPEND-ONLY USDJPY Q02 PENDING`

## Selection and duplicate control

The 66-relationship scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` produced only two strict
survivors, and both are already built. The current sign-aware coverage receipt
in `docs/research/FX_COINTEGRATION_QM5_1257_PREFLIGHT_BLOCKER_2026-09-02.md`
records zero reputable unbuilt identities. Creating a new card would therefore
duplicate the covered frontier.

The anchors are also past Q02 rather than blocked there:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, Q04 FAIL.

This unit took the requested fallback and advanced the approved existing FX
basket `QM5_10025_rw-fx-broad-pairs`. Its reputable source record is Robot
Wealth's *Index of Strategies* (`dcbac84f-6ecf-5d21-9630-50faa69306ec`), and
its runtime card is G0 `APPROVED` with R1-R4 `PASS`. The structural H4 method
selects a pair monthly from seven liquid FX majors using frozen OLS,
correlation, and an ADF-style residual screen. It has no ML, banned indicator,
grid, martingale, or intramonth coefficient adaptation.

## Bound zero-trade evidence

USDJPY Q02 work item `050dd2ea-e9d0-475f-b5ad-40c2206867ff` completed
`done / ZERO_TRADES`. Its one valid model-4 report covered `2018.07.02` through
`2022.12.31`, had no OnInit failure, and recorded zero trades against a floor
of 25. The exact evidence is:

`D:\QM\reports\work_items\050dd2ea-e9d0-475f-b5ad-40c2206867ff\QM5_10025\20260901_215109\summary.json`

- The source and deployed setfiles matched, and the EX5 remained stable.
- USDJPY and all six possible partner histories and real ticks synchronized.
- The news-calendar preflight was `OK`.
- The 1,412-event logger sample contained `INIT_OK`, but zero pair-selection,
  pair-signal, entry, or order markers.
- Bound hashes were MQ5
  `fd0a18d8710dc8bd0d089ab34b9c881de65e971f0916ba540b34c53b2aa120ff`,
  EX5 `9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc`,
  and setfile
  `2d8a1ba1871c229d00b49458dcbd6dbd152d24c170d76404bace39cdea3be53c`.

The harness and setup layers therefore pass. The first unresolved layer is the
entry hook: the old binary could not distinguish “no pair qualified,” “no
z-score crossed,” and “a valid candidate was rejected.” This is an
observability classification, not a claim that the economic rule is defective.

## Bounded repair

The EA now exposes `strategy_debug=false`. When explicitly enabled, it emits:

- one initialization record;
- one candidate outcome per partner during each monthly selection and one
  monthly aggregate selection record;
- a signal-candidate record only on the first bar outside the entry band; and
- the corresponding first rejection reason for no-trade/news filters or
  symbol, quote, stop, risk, lot, and order preparation.

Only the USDJPY evidence set enables the switch. The monthly and latched event
bounds prevent per-tick log amplification. Two explicit spread-buffer size
checks were also added after strict hardening identified the dynamic arrays.
No symbol, threshold, hedge coefficient rule, risk rule, entry, or exit changed.

Current execution hashes are:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `49e0c78c0e45fa39b05580216003ee523839b664844a82e3a7d3d943030e069a` |
| EX5 | `030e7acc63a735a514c5490000eed4d4bf062bf8f6ee8e4da34a601da8f9ba1e` |
| USDJPY H4 set | `9567e0f91b1e6892eadc822a2f6ee4f06482a80ba30c50ccfbf4a205d2acda70` |

## Verification

- Registry, deterministic magic allocation, and EA-directory guard: PASS.
- MetaEditor strict compile: PASS, zero errors and zero warnings.
- `validate_spec_doc.py`: PASS, 1/1.
- Basket symbol scope: `BASKET_OK`, zero violations; the manifest declares all
  seven runtime symbols.
- `validate_build_guardrails.py`: PASS, zero findings.
- Basket work-item tests: 18 passed.
- Basket-order and manifest tests: 59 passed, 2 subtests passed.

The first canonical build-check run identified only two unbounded dynamic
spread-buffer findings; both are repaired. A post-repair canonical wrapper
retry correctly refused ad-hoc execution with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` while an unrelated governed factory
terminal was active. It was not bypassed. The final strict MetaEditor compile
and the specialized validators above all ran after those guards were added.

## Q02 handoff

Governed append-only Q02 row `e49888a1-6dbe-45b7-bb4f-29461bbcfb0c` is
pending, unclaimed, and attempt 0. It preserves the zero-trade predecessor and
binds the exact current hashes above, `USDJPY.DWX / H4`, the seven-symbol
`basket_manifest.json`, and the same `2018.07.02`-`2022.12.31` window.

The set contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and portfolio
weight 1. SH3 identity enforcement and gate contract v4 are active. There is
exactly one open USDJPY Q02 row; the other four open QM5_10025 rows use
different host symbols. Execution remains owned by the paced farm and was not
manually dispatched.

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
| --- | --- | --- | --- | --- | --- | --- | --- |
| QM5_10025 / USDJPY H4 | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` | Not yet identified; entry-hook decisions were unobservable after harness/setup passed | Default-off bounded selection/signal/reject diagnostics | PASS, 0 errors / 0 warnings | Old run: 0 decision markers because none existed; rerun pending | Old run: 0; rerun pending | Classify monthly qualification versus signal/rejection counts from the governed rerun |

## Capacity and safety boundary

Five pre-enqueue CPU samples averaged 61.95% and peaked at 64.99%, below the
97% stop ceiling. No additional tester or manual backtest was started.

No portfolio-admission, KPI, or Q08-contribution gate; T_Live manifest or
terminal; AutoTrading setting; or live-use authority was changed.

Machine-readable companion:
`artifacts/qm5_10025_usdjpy_zero_trade_recovery_20260902.json`.
