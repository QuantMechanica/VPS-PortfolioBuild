# P7 Statistical Validation

## PBO ownership

- `framework/scripts/p7_statval.py` is a gate checker, not a PBO estimator.
- P7 reads `pbo_pct` from the sweep-pass input rows (`--sweep-pass-rows`).
- If `pbo_pct` is absent, P7 defaults to a fail-safe value (`100.0`) and fails the hard gate (`PBO < 5%`).

## Deterministic source of `pbo_pct`

- Canonical calculator: `framework/scripts/pbo_calculator.py`.
- Method: combinatorially symmetric cross-validation (CSCV), deterministic for fixed input.
- Required input schema for the calculator:
  - `config_id`: strategy parameter configuration id
  - `slice_id`: validation slice id (even count; symmetric split)
  - `score`: objective value used to rank configurations (higher is better)

## Hand-off contract into P7

1. Run parameter sweep and export CSCV score rows.
2. Run `pbo_calculator.py` to compute `pbo_pct`.
3. Persist `pbo_pct` into the P7 sweep-pass rows consumed by `p7_statval.py`.
4. Run `p7_statval.py`; P7 enforces `pbo_pct < 5.0`.

## Example

```bash
python framework/scripts/pbo_calculator.py \
  --input D:/QM/reports/pipeline/QM5_1001/P3/cscv_scores.csv \
  --out D:/QM/reports/pipeline/QM5_1001/P3/pbo_result.json
```
