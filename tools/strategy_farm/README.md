# Option A Strategy Farm

This is the deterministic local controller for the QuantMechanica strategy farm.
It uses explicit queues, SQLite state, and foreground commands that can later be
scheduled once the loop is proven.

Runtime state lives outside the repo by default:

```powershell
D:\QM\strategy_farm
```

Use `farmctl.py` to initialize state, seed sources, inspect status, and claim
the next single source for research.

```powershell
python .\tools\strategy_farm\farmctl.py init
python .\tools\strategy_farm\farmctl.py seed-sources
python .\tools\strategy_farm\farmctl.py status
python .\tools\strategy_farm\farmctl.py next
python .\tools\strategy_farm\farmctl.py claim-source
python .\tools\strategy_farm\farmctl.py events --limit 20
```

The first acceptance test is intentionally small:

1. exactly one source is active,
2. Claude researches only that source,
3. Codex builds/backtests only approved cards,
4. every transition is recorded in `state\farm_state.sqlite`,
5. the loop chooses the next action deterministically.

After Claude writes research notes, record the transition explicitly:

```powershell
python .\tools\strategy_farm\farmctl.py set-source-status <source-id> notes_ready --notes-path D:\QM\strategy_farm\artifacts\source_notes\<file>.md
```
