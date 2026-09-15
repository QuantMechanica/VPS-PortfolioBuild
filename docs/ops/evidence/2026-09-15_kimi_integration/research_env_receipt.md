# Research venv provisioning receipt — slice C5

- Date: 2026-09-15 (UTC)
- Purpose: the ONLY runtime write authorized for slice C5 — provision the isolated
  uv-managed research venv for the offline DISCOVER/ML layer
  (`docs/ops/KIMI_EDGE_DISCOVERY_DESIGN.md` §2.2). The farm Python311 MT5 worker
  runtime is deliberately left untouched.
- Provisioned by: `tools/strategy_farm/research/research_env.py::provision_venv`.

## Outcome: OK

Wheels resolved online; nothing had to fall back to pip-into-farm-Python. `ok: true`.

## Environment

| Item | Value |
|---|---|
| uv version | `uv 0.11.16 (135a36367 2026-05-21 x86_64-pc-windows-msvc)` |
| uv path | `C:\Users\Administrator\.local\bin\uv.EXE` |
| venv path | `D:\QM\research\venv` |
| venv base interpreter | CPython 3.11.9 at `C:\Python311\python.exe` (template only) |
| D: free at provisioning | 70.5 GB |

## Commands (returncode 0 for both)

```
uv venv D:\QM\research\venv
uv pip install --python D:\QM\research\venv pandas duckdb scipy scikit-learn statsmodels
```

`uv pip install` resolved 19 packages in ~0.44s and installed in ~4.84s. (uv warned
that hardlinking fell back to a full copy because the uv cache (C:) and the target
(D:) are on different filesystems — cosmetic, install succeeded.)

## Resolved package set (`uv pip freeze`)

```
cloudpickle==3.1.2
duckdb==1.5.5
formulaic==1.2.2
interface-meta==2.0.1
joblib==1.6.0
narwhals==2.26.0
numpy==2.4.6
packaging==26.3
pandas==3.0.5
patsy==1.0.3
python-dateutil==2.9.0.post0
scikit-learn==1.9.1
scipy==1.17.1
six==1.17.0
statsmodels==0.15.0
threadpoolctl==3.6.0
typing-extensions==4.16.0
tzdata==2026.4
wrapt==2.4.1
```

- Requested top-level packages (task list): pandas, duckdb, scipy, scikit-learn, statsmodels.
- Requirements/lock sha256 (of the freeze text above, trailing newline):
  `01058c2a5533928bf3b06d06dd0dac0a5fad602b3d44bbac92ca6c5b9064ebfa`
  (without trailing newline: `a738374f97d0701d7ae10bf12881b0ee964800eb0a9febf726704eb36153efef`).

## Isolation verification

| Interpreter | pandas | duckdb | Note |
|---|---|---|---|
| Farm Python311 `C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe` (MT5 worker runtime) | False | False | UNTOUCHED — not pip-installed into |
| Research venv `D:\QM\research\venv\Scripts\python.exe` | 3.0.5 | 1.5.5 | scipy/sklearn/statsmodels also import cleanly |

`uv pip install --python <venv>` targets only the venv site-packages; the base
template interpreter and the farm runtime are not modified.

## Notes

- The research package modules (`observe_projector.py`, `experiment_memory.py`,
  ledgers, `preregister.py`, `mechanization_check.py`, `research_env.py`) depend on
  stdlib `csv`/`sqlite3`/`json` only, so the deterministic projectors run on the
  farm Python; the heavier DISCOVER ML work runs under this venv.
- Rebuild is idempotent: re-running `provision_venv` recreates the venv (uv venv
  overwrites) and re-resolves the same set.
