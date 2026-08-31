# QM5_41250 WTI Permutation-MAD Scale Trend Q02 Enqueue

Date: `2026-08-31`

Branch: `agents/board-advisor`

## Outcome

The commodity/energy mission produced one new source-approved direct-WTI
structural sleeve. `QM5_41250_wti-mperm-scale-tr` passed a source-fresh Q01
compile and entered Q02 exactly once as pending work item
`fc9d1764-2071-4b1c-9602-ed0302366985` for `XTIUSD.DWX / D1`.

No manual backtest or dispatch tick was run. No live, deployment, or portfolio
state was touched. This is a testable crude-oil sleeve; it is not a performance,
certification, or realized-decorrelation claim. Q09 retains portfolio-overlap
authority.

## Edge and non-duplicate boundary

At the first eligible broker-month transition, the EA reconstructs thirteen
consecutive completed WTI month-end closes and derives twelve adjacent log
returns. It fixes the oldest six returns as the old block and newest six as the
recent block. Both blocks use the exact even-sample median and median absolute
deviation. Entry requires a positive recent-minus-old MAD expansion whose
inclusive upper-tail count is at most 416 across all `C(12,6) = 924` fixed-size
label assignments. Trade direction is the sign of the actual recent block's
arithmetic mean.

The rule is mechanically distinct from the adjacent WTI Welch mean-shift,
nested volatility-of-volatility, monthly OHLC range-expansion, and
volatility-normalized momentum families, and from the certified XNG RSI
pullback. The corrected-root preallocation scan found no exact identity across
4,749 registry rows, 1,387 cards, and 45 Strategy Wiki nodes. Its nearest fuzzy
neighbor was manually resolved as a different location statistic and null.

## Source and governance

- Source approval: commit `45721646e9`.
- EA identity reservation: commit `69814733e5`.
- G0-approved Strategy Card: commit `1a61f7495f`.
- Deterministic slot-zero magic allocation: commit `70b822a28f`.
- EA, SPEC, reference fixtures, and fixed-risk preset: commit `1aec853fb5`.
- Source-fresh binary and sealed setfile: commit `ef051dc117`.

The durable source packet preserves complete-read peer-reviewed WTI
time-series-momentum evidence from Moskowitz, Ooi, and Pedersen (2012). The
exact robust-scale/permutation conjunction is explicitly identified as an
untested QM synthesis rather than attributed to that paper.

## Q01 evidence

- Work item: `ee53e419-4162-4149-bf2a-d571d258652f`, terminal T3.
- MetaEditor: PASS, zero errors, zero warnings.
- Strict build check: PASS; failure classes empty.
- MQ5 SHA-256:
  `709D92CE816B88CFC57C42F013BC9DC02B8F2FF592EADB4CBE76DFA75CF04313`.
- EX5 SHA-256:
  `E7C7251B847168547F9258064630B3408A90069B8E4C13B92394C8A1902C5511`.
- Compile-evidence SHA-256:
  `EAFB855FC7CC00EFBC7DBF41D8D92CCCD9A7CA04E0BEAE4A0D5CB8F78D3CC303`.
- Final setfile SHA-256:
  `56543AB3B9715F80E245B7122E08409FB23A6011FB60788C89B6F679031BF6F3`.
- Deterministic reference suite: 11/11 PASS.
- SPEC and strategy-entry validation: PASS.
- Canonical and local cards: schema PASS and byte-identical.

The sole backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Paced Q02 enqueue

Immediately before the canonical build recorder appended Q02, the five-sample
whole-host CPU window was `90.6260%`, `96.8702%`, `94.0495%`, `89.9575%`, and
`93.0784%` (average `92.9163%`, maximum `96.8702%`). Every sample remained at
or below the 97% hard ceiling.

Readback recorded the Q02 row as pending, attempt zero, and unclaimed, with a
one-EA priority-track cohort, active custom-history admission, and 108 selected
archive rows. The canonical build recorder was the enqueuer; this session did
not run a dispatch tick.

## Safety boundary

AutoTrading was not toggled. `T_Live`, its manifest, deploy manifests, the
portfolio gate, portfolio admission, and certification state were untouched.

Machine-readable receipts:
`artifacts/qm5_41250_build_result_20260831.json` and
`artifacts/qm5_41250_wti_mperm_scale_tr_q02_enqueue_20260831.json`.
