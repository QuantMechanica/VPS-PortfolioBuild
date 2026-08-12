# STR-002 / QM5_20101 — Smoke record (2026-07-24)

Not run: indicator EA (iMA EMA100 handle gates NoTradeFilter) — the only free
tester host (T5) has a dead built-in indicator engine (control-proven, see
STR-097 06_smoke.md forensics); a 0-trade result would be unattributable.
OWNER directive 2026-07-24 ("einfach in die Factory einreihen, keine
Priorisierung") waives the ad-hoc smoke; Q02 on a healthy factory terminal is
the aliveness check. Watch item: if Q02 returns 0 trades on all 4 symbols,
suspect the strict same-bar flip/session conjunction before suspecting the
edge (STR-097 lesson: verify the entry path actually runs).
