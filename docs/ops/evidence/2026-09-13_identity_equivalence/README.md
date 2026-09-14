# Identity-Equivalence Proofs for Symbol-Literal Rebuilds — 2026-09-13

## Purpose

Some rebuilt EAs are re-registered as new identities (Hard Rule "rebuilt EX5 =
new identity from Q02") solely to satisfy the Hard Rule "symbols are inputs":
the only source change is replacing hard-coded `".DWX"` symbol literals by
inputs. Their behaviour should be indistinguishable from the original. This
evidence set records a **deterministic proof** of that equivalence, so a rebuilt
identity can inherit the original's *deployability* for the book without any gate
verdict row ever being manufactured for the new identity.

## OWNER order

OWNER 2026-09-13 ("Alle Punkte ... umsetzen"): build a mechanism by which a
rebuilt identity whose full-window Q02 replay is *provably behaviour-identical*
to the original can inherit the original's DEPLOYABILITY (the deploy manifest
cites the proof; the original's gate evidence stays the strategy evidence),
WITHOUT manufacturing any gate verdict rows for the new identity — its own
Q03..Q10 chain keeps running normally. This is a proof artifact + decision
record, not a pipeline shortcut.

## The JPY tick-value finding (why "exact" is impossible for some symbols)

`RISK_FIXED` lot sizing divides a fixed risk amount by the stop distance times
the **symbol tick value**. For JPY-quoted pairs the tick value (expressed in the
USD account currency) depends on the prevailing USDJPY quote at the moment the
strategy tester queries it. The original (`QM5_12969`) ran in August; the
rebuild (`QM5_41470`) ran in September, at a different USDJPY level. Result: the
rebuild sizes **every** deal one lot step smaller (0.91 vs 0.92, ...), and net
profit scales by the same factor (ratio ≈ 0.989). Every other deal attribute —
time, symbol, type, direction, entry price, comment — is bit-identical across
all 335 deals.

Consequence: a byte-exact equivalence proof is impossible for such symbols. The
proof is therefore **lot-normalised**: it requires the entry/exit decisions to be
identical and the volume/PnL to differ only by a bounded, sign-consistent scale
factor (the ratified tolerances below).

## Proof tolerances (OWNER-ratified constants)

| constant | value | meaning |
|---|---|---|
| `volume_ratio_abs_tol` | 0.02 | max `|rebuilt/original − 1|` per deal |
| `volume_max_step_lots` | 0.01 | max `|rebuilt_vol − original_vol|` in lots |
| `pnl_per_lot_rel_tol` | 0.005 | per-deal profit/volume relative equality |
| `net_ratio_abs_tol` | 0.05 | recorded net-ratio band (informational) |

These live in `PROOF_TOLERANCES` in the tool and are printed into every proof.

## Verdicts

* `EQUIVALENT_EXACT` — everything identical, including volume.
* `EQUIVALENT_LOT_NORMALISED` — only volume/PnL scale differ, within tolerance.
* `NOT_EQUIVALENT` — listed structural reasons; nothing is inherited.

## Results (five pairs; all five rebuilds now proved)

| pair | symbol | deals (n) | field-exact deals | vol ratio min/max | net ratio | verdict |
|---|---|---|---|---|---|---|
| QM5_12969 → QM5_41470 | USDJPY.DWX | 335 | 335 (all) | 0.9882 / 0.9919 | 0.989 | **EQUIVALENT_LOT_NORMALISED** |
| QM5_13054 → QM5_41473 | XTIUSD.DWX | 99 | 99 (all) | 1.0000 / 1.0000 | 1.000 | **EQUIVALENT_EXACT** |
| QM5_21505 → QM5_41474 | XAGUSD.DWX | 159 vs 151 | — | 0.3704 / 3.0000 | 1.306 | **NOT_EQUIVALENT** |
| QM5_12778 → QM5_41471 | AUDUSD+EURJPY cointegration D1 | 389 vs 261 | 131/261 compared | — | — | **NOT_EQUIVALENT** (2026-09-14) |
| QM5_13117 → QM5_41472 | EURGBP+AUDJPY cointegration D1 | 225 vs 225 | 113/225 compared | — | — | **NOT_EQUIVALENT** (2026-09-14) |

"field-exact" = deals matching on (time, symbol, type, direction, price,
comment); deal count includes the initial balance/deposit deal.

Notes:
* **USDJPY** — 334 trading deals each one lot step smaller (JPY tick-value
  effect above); all decisions identical. Inheritance eligible.
* **XTIUSD** — the clean case: bit-identical deals and volumes. Inheritance
  eligible.
* **XAGUSD** — the rebuild genuinely diverged: deal count 159 → 151, 132 deals
  differ on core fields, and the set file even differs on
  `strategy_vol_percentile` (`33` vs `33.0`). This is **not** a pure symbol-
  literal rebuild; it must earn its own Q02..Q10 evidence and inherits nothing.
* **AUDUSD+EURJPY (12778→41471)** — deal count diverges 389 vs 261 (128 fewer
  in the rebuild) and 130/261 compared deals differ, mostly on the `comment`
  field (`QM5_12778_...` vs `QM5_41471_...` prefix, expected, plus real
  structural drift beyond the rename). Basket/cointegration EAs are more
  sensitive to leg-symbol resolution order than single-symbol EAs. Not a pure
  symbol-literal rebuild by this proof; earns its own Q02..Q10 chain, inherits
  nothing from 12778.
* **EURGBP+AUDJPY (13117→41472)** — deal counts match (225 vs 225) but
  112/225 compared deals differ on core fields. Same conclusion: not
  equivalent, no inheritance from 13117.

### Proof artifacts

| pair | proof.json | proof.sha256 |
|---|---|---|
| USDJPY | `D:/QM/reports/identity_equivalence/QM5_12969__QM5_41470/USDJPY.DWX/proof.json` | `3648983baea047f4f0a0f48d922ea442646bcb00022e7cdaca498fe31635828a` |
| XTIUSD | `D:/QM/reports/identity_equivalence/QM5_13054__QM5_41473/XTIUSD.DWX/proof.json` | `fddbd6a7039762698bb1d619531906d9f2bfc21a943a44680a6fa92808eca3a2` |
| XAGUSD | `D:/QM/reports/identity_equivalence/QM5_21505__QM5_41474/XAGUSD.DWX/proof.json` | `69028612d61864ca2ab3163d4d12ca0ad3b04a8482379f2d4241ad22ef945f73` |
| AUDUSD+EURJPY | `D:/QM/reports/identity_equivalence/QM5_12778__QM5_41471/QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1/proof.json` | `70f86e0ad1ad92ddb0aea23973a1fb19182880f2e71095f3208eea296ec6f588` |
| EURGBP+AUDJPY | `D:/QM/reports/identity_equivalence/QM5_13117__QM5_41472/QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1/proof.json` | `d91ca2d35ade113f5562a485a0955edc0af822cd59d577fe15257233da5e1086` |

Each proof records the input SHAs (report_sha256, tester.ini sha, set-file sha,
compile-evidence ex5 sha and work-item ex5 sha, summary sha), the full check
detail, the tolerances, and the tool's own sha256. `verify` re-hashes the inputs
and confirms the proof still binds; all three currently verify `ok=True`.

## What the proof does NOT do

* It **never** creates or copies a gate verdict row for the new identity.
* It does **not** change the census, pool definition, or any pipeline state.
* It reads `farm_state.sqlite` **read-only**; it starts no terminal, touches no
  set/ex5/report, and never approaches T_Live.
* The rebuilt identity's own Q02..Q10 chain continues normally regardless of the
  verdict.
* A proof is *evidence*, not authorization: inheritance for the book requires the
  OWNER-ratified rule (see the decision record) and a receipt.

## Reproduce

```powershell
cd C:/QM/repo
# build (writes proof.json + proof.sha256 under the out-root)
python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove `
  --original 27a43902-90b1-4581-8c91-a911332cf4a8 `
  --rebuilt  7ee74893-fb56-4897-b2ff-89eab5491481
python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove `
  --original b43f34fe-53e1-4e4e-9d78-d88b6a2fdc2e `
  --rebuilt  152523e4-d30b-46d6-b96a-60b669f82a36
python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove `
  --original 253f23f0-5bb7-4840-b60f-fba2f5ebde9e `
  --rebuilt  b02b0a87-6f7f-4400-ad54-8e1503a84e43
# 2026-09-14, once their own Q02 rows existed: 12778->41471 and 13117->41472 (both NOT_EQUIVALENT)
python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove `
  --original 462e2f78-8589-48eb-8bca-25c804b67bf8 `
  --rebuilt  26aaec94-02ee-4a71-9eed-68b624b45adc
python -X utf8 tools/strategy_farm/identity_equivalence_proof.py prove `
  --original f56d3034-abfe-4337-a103-1a85a50ad208 `
  --rebuilt  1f8a23d2-6824-4d56-916b-6c76a2b1ed21
# re-check a proof still binds its inputs
python -X utf8 tools/strategy_farm/identity_equivalence_proof.py verify `
  --proof D:/QM/reports/identity_equivalence/QM5_12969__QM5_41470/USDJPY.DWX/proof.json
# tests
python -X utf8 -m pytest tools/strategy_farm/tests/test_identity_equivalence_proof.py -q
```

Default `--out-root` is `D:/QM/reports/identity_equivalence`.
