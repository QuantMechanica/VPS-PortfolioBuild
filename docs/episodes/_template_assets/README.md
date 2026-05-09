# Episode Pack Asset Generator

Generates the three chart PNGs required by `docs/episodes/_template.md`
from pipeline output artifacts (`summary.json` + `mc_distribution.csv`).

## Quick start

```bash
# from an episode pack directory, e.g. episodes/EP05-QM5_1003-davey-eu-night/
python ../../docs/episodes/_template_assets/gen_plots.py
# PNGs appear in ./assets/
```

Explicit paths:

```bash
python gen_plots.py \
  --summary path/to/summary.json \
  --mc      path/to/mc_distribution.csv \
  --out     path/to/assets/
```

## Required input files

### summary.json

Produced by the pipeline runner at P3 sweep completion. Must contain:

| Key path | Type | Description |
|----------|------|-------------|
| `p2_baseline.equity_curve` | `[[int, float], ...]` | `[trade_index, equity]` pairs |
| `p2_baseline.modal_verdict` | `"PASS"` / `"FAIL"` | Displayed in chart title |
| `p3_sweep.grid_pf_matrix` | object | See schema below |
| `p3_sweep.pass_cells` / `total_cells` | int | Displayed in title |
| `p3_sweep.best_row_idx` / `best_col_idx` | int | Highlights best cell |

`grid_pf_matrix` sub-schema:

```json
{
  "rows": [20, 30, 40],
  "cols": [15, 20, 25],
  "values": [[1.1, 1.4, 1.3], [1.5, 1.7, 1.6], [1.2, 1.3, 1.1]]
}
```

Full example in `gen_plots.py` module docstring.

### mc_distribution.csv

One row per MC iteration. Required columns: `max_dd_pct`, `sharpe`.
Optional: `iteration`, `final_equity`.

```csv
iteration,max_dd_pct,sharpe,final_equity
1,-12.3,0.82,11234.56
2,-9.1,1.05,12100.00
```

## Output

| File | Description |
|------|-------------|
| `assets/equity_curve.png` | P2 baseline equity curve |
| `assets/p3_heatmap.png` | P3 parameter sweep PF heatmap with best-cell highlight |
| `assets/mc_distributions.png` | P4 MC max_dd + sharpe histograms |

## Dependencies

```
matplotlib
numpy
pandas
```

All are standard in any V5 Python environment. No additional install needed if
the pipeline runner environment is active.

## Notes

- Plots use brand colors from `branding/brand_tokens.json` (dark navy + emerald).
- Missing or malformed inputs produce a `SKIP` warning and continue — the generator
  never aborts on partial data.
- PNGs are 150 dpi. Increase `dpi` arg in each plot function for print-quality output.
