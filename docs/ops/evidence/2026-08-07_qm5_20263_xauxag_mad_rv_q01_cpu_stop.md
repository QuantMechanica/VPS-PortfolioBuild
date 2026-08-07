# QM5_20263 XAU/XAG Robust Ratio Reversion Q01 And CPU Stop

Date: 2026-08-07 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20263_xauxag-mad-rv` is built and Q01 is `PASS`. Q02 is
`NOT_ENQUEUED_CPU_CEILING`: the binding path-anchored capacity sample found
nine T1-T10 factory terminals executing against the paced ceiling of seven.
No enqueue dry run, apply-mode enqueue, dispatch command, smoke test, or manual
backtest was run after that sample.

## Edge And Non-Duplicate Boundary

The EA aligns 64 completed D1 timestamps for `XAUUSD.DWX` and `XAGUSD.DWX`
and forms `ln(XAU close) - ln(XAG close)`. It computes independent current
and prior 63-observation robust scores from each window's median and median
absolute deviation:

```text
robust_z = 0.6744897501960817 * (latest_ratio - median) / MAD
```

A fresh crossing above `+2.0` sells XAU and buys XAG; a fresh crossing below
`-2.0` buys XAU and sells XAG. The package closes after convergence inside
`+/-0.5`, invalid state or composition, or 45 calendar days. Each leg receives
half of one aggregate fixed-cash budget after independent
`3.5*ATR(20,D1)` stop normalization. An entry attempt is persisted before
execution checks, and the threshold-crossing rule prevents re-entry inside the
same later excursion.

The deterministic pre-allocation review covered 4,320 EA-registry rows and all
840 card files. It found no exact ID, slug, strategy-ID, or gold/silver
median/MAD mechanic collision. Manual review resolved the closest systems:

- `QM5_12577_cme-xauxag-ratio` and `QM5_20157_xau-xag-ratio` use an arithmetic
  mean and standard deviation on a fixed log ratio;
- `QM5_20161_xauxag-ols-rv` estimates a rolling OLS hedge ratio and trades
  standardized residuals;
- `QM5_13205_xau-xag-qc` uses quantile-cointegration state;
- `QM5_20254_xauxag-vr-fade` gates a conventional ratio z-score with a monthly
  variance-ratio anti-persistence test; and
- `QM5_20249_xauxag-vr-spread` trades monthly relative-memory direction.

The median, MAD, fixed consistency scale, separate current/prior windows,
fresh-cross rule, and no-reentry excursion boundary are load-bearing. Replacing
them with mean/standard deviation collapses the candidate into an existing
ratio-z family. The opposite-leg package seeks a different return driver from
the certified XAU/SP500/NDX/XNG book, but neutrality and decorrelation are not
claimed; Q09 alone could establish realized overlap after preceding gates pass.

## Source And G0 Record

The bounded approved packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MAD-2026/source.md`. It joins:

- Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`;
- Yaya, Vo, and Olayinka (2021), *Resources Policy* 72, 102045, DOI
  `10.1016/j.resourpol.2021.102045`; and
- CME Group, "Gold & Silver Ratio Spread."

The sources support a potentially state-dependent gold/silver long-run
relationship and the ratio as an intermarket spread. Median/MAD, the fixed
window and thresholds, crossing rule, CFD translation, fixed risk, ATR stops,
and lifecycle controls are transparent QM hypotheses. No source profitability,
density, CFD-equivalence, neutrality, or portfolio-correlation result transfers.

G0 authorization is
`decisions/2026-08-07_qm5_20263_xauxag_mad_rv_g0.md`.

## Deterministic Allocation And Q01 Evidence

- EA ID/slug: `QM5_20263` / `xauxag-mad-rv`.
- Strategy ID: `SCHWEIKERT-CME-XAUXAG-MADRV-2026_S01`.
- Symbols/slots/magics: `XAUUSD.DWX` / 0 / `202630000` and `XAGUSD.DWX` /
  1 / `202630001`.
- EA-registry SHA-256:
  `A3851C529D0D8E53238097C669F4C013A5E436B8C0C81C64D7241AC2A63BF8BA`.
- Magic-registry SHA-256:
  `B2E5B2DD72C8C8F09633E8C59A83889577D2D40E1484EBE503685B61D0A50594`.
- Generated resolver SHA-256:
  `34B53C6467BE96F5F300E0F898C7DF7698D595EFD5F691E325E0F741644D7604`;
  both new magics are present and the generator kept 15,555 rows with zero
  dropped.
- Card extraction schema/ML lint: PASS on intake, canonical, and build copies;
  no missing sections or forbidden hits.
- G0 readiness lint: PASS with no missing fields.
- Build prerequisite guard: PASS for EA registry, magic registry, and EA
  directory.
- SPEC validation: PASS, one target and zero failures.
- Build guardrails: PASS with no findings.
- Symbol-scope validation: `BASKET_OK`, zero violations, with XAU and XAG
  declared in `basket_manifest.json`.
- Target-scoped strict build gate:
  `D:/QM/reports/framework/21/build_check_20260807_100806.json` (`PASS`, strict,
  zero failures and zero warnings).
- The gate's compiler invocation:
  `D:/QM/reports/compile/20260807_100807/summary.csv` (`PASS`, zero errors and
  zero warnings).
- Compile log:
  `C:/QM/repo/framework/build/compile/20260807_100807/QM5_20263_xauxag-mad-rv.compile.log`.
- EX5 size: 377,704 bytes.
- Setfile risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; generated header build hash
  `459c5cfca3029e384edee908b97161ac097fa931b3b629a578955622e88b97c0`.
- Manual smoke/backtest: none.

Artifact SHA-256 values after the Q01/capacity-stop status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `224488BFA0475C6ED0E0174D31B3BBB8C9AECCB2621ABE3FFDF6ED7BBBAA8E22` |
| Canonical/build card | `A05AFABC5F0A508981F0C24AE784F14F953B1740254ECB33AA2CEA8A9F8B07D2` |
| MQ5 | `70C5AC744C19699A91C8031A723E9B28B3776FEEAC3ABC949849E140C315D685` |
| EX5 | `B518B5BAAA85ECB64DFDBCABFDCC48C6633F3FD74B6492D490DBD59E532EED3E` |
| SPEC | `DD02FBF03EED1588B2B548D1F6A9822057E4F06DAD6A52FF48FC72BA79FF48FE` |
| Basket manifest | `2923954265B7575C185EE5BE62DB378FBAF0430FF6722646EC5E89B4C3F55046` |
| Backtest set | `F124CB8232427AD283704C9B2C11807F93FEDDB8829880942436F63C1A67A47F` |

## Q02 Capacity Stop

`farmctl mt5-slots` sampled the governed processes at
`2026-08-07T10:04:13+00:00` and found nine exact factory terminals executing:

| Terminal | PID | Observed phase/state |
|---|---:|---|
| T1 | 18616 | Q02, `QM5_12538` / `USDCHF.DWX` |
| T3 | 8724 | Q02, `QM5_11390` / `GBPUSD.DWX` |
| T4 | 15132 | Q02, `QM5_12538` / `NZDUSD.DWX` |
| T5 | 9104 | Q02, `QM5_10369` / `GDAXI.DWX` |
| T6 | 20648 | Q02, `QM5_10574` / `EURJPY.DWX` |
| T7 | 13764 | Q07, `QM5_11177` / `XAUUSD.DWX` |
| T8 | 15820 | Q02, `QM5_12512` / `GBPJPY.DWX` |
| T9 | 12816 | Q09_NEWS, `QM5_11422` / `USDCAD.DWX` |
| T10 | 16108 | Q02, `QM5_20192` / logical XAU/XAG basket |

Only executing terminal processes rooted under
`D:/QM/mt5/T1..T10/terminal64.exe` count. The separate
`C:/QM/mt5/T_Live` and FTMO processes were observed by the read-only command
but excluded and were not accessed or changed. The governed sample is 9/7 and
therefore binding.

Per the mission's CPU-stop condition, no enqueue dry run or apply command was
issued, and no Q02 work-item ID was created by this task. A later paced
operator may take a fresh immediate capacity sample and, only below the
seven-terminal ceiling, use the target-scoped sweep workflow for `QM5_20263`
and logical basket `QM5_20263_XAU_XAG_MADRV_D1`. This is a ready-but-capacity-
blocked handoff, not a Q02 screening verdict.

## Safety Boundary

- No apply-mode enqueue, dispatch tick, manual backtest, smoke test, or
  downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading and `T_Live` were not touched.
- The portfolio gate and T_Live manifest were not touched.
- The unrelated pre-existing `QM5_11390` working-tree edits were preserved and
  excluded from this mission's commit.
