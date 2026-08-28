# Cockpit SYSTEM task and last-good publication hardening

Router task: `8e8ad8b4-8193-4f30-b940-5bc947e26c34`

## Result

`QM_StrategyFarm_Cockpit_2min` now runs without an interactive user session:

- principal: `NT AUTHORITY\SYSTEM`, `ServiceAccount`, highest privileges;
- action: Python 3.11 `pythonw.exe` directly executes
  `C:\QM\repo\tools\strategy_farm\render_cockpit.py`;
- no `run_in_console_session.ps1` dependency remains;
- the naturally scheduled 09:09 local run completed with Task Scheduler result
  `0` and refreshed `D:\QM\strategy_farm\dashboards\cockpit.html` at 09:09:46.

The task action was already in the correct direct-SYSTEM form when this router
cycle inspected it, so this cycle did not rewrite the task definition or touch
`FactoryON_AtLogon`.

## Last-good output guarantee

`render_cockpit_v2.py` now writes each HTML publication to a same-directory
temporary file, flushes it, and publishes with `os.replace`. A failed render or
failed replace therefore leaves the previous destination byte-for-byte intact;
the temporary file is removed on failure. This applies to the primary cockpit,
its v2 alias, and the linear-frontier side page.

The existing generated-time display remains the stale indicator: if a later
render fails, the retained page's client-side age continues increasing instead
of presenting a partial new document.

## Verification

```text
python -m py_compile tools/strategy_farm/render_cockpit_v2.py
python -m pytest tools/strategy_farm/tests/test_render_cockpit_v2.py -q
13 passed in 0.70s
```

The added failure-injection test forces `os.replace` to raise, verifies that the
old `cockpit.html` still contains `last-good`, and verifies that no temporary
file remains.

## Rollback

Revert only the commit containing this evidence and the atomic writer change.
The scheduled-task definition needs no rollback because this cycle did not
modify it. Reverting restores direct `Path.write_text` publication; it does not
change any database, terminal, Factory, T_Live, or AutoTrading state.
