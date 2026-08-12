# KS arming after OWNER's T_Live restart 2026-07-31 13:06Z — result + root cause

**Restart:** OWNER closed/reopened T_Live (terminal64 PID 11088, started 13:06:20Z,
market open, Friday). All 24 book sleeves re-initialized 13:06:46–13:10:56Z
(full-log INIT_OK scan; the 4 stale non-book logs 10476/10692/10715/10940 have
no fresh init — they are not in FINAL-24).

## Arm state per sleeve (authoritative full-log events, 13:06–13:11Z)

- **LOADED — 14 of 24:** 10403|XAUUSD, 10706|GBPUSD, 11165|EURUSD, 11165|AUDCAD,
  11708|EURUSD, 12778|AUDUSD, 12969|USDJPY, 13117|EURGBP, 13128|NDX,
  13213|USDJPY, 13301|GDAXI, 1556|XAUUSD, 1567|EURUSD.
  Includes both Phase-1 deploys (1567, 13117) and **12778 — whose chart is back
  and armed** (the Sunday chart-restore item is thereby already resolved).
- **ABSENT expected — 2:** 10440|NDX (Q10 FAIL dd 31 %, no eligible baseline),
  10513|XAUUSD (provenance hold).
- **ABSENT unexpected — 9:** 10911|GDAXI, 10919|XTIUSD, 10939|GBPUSD,
  11132|SP500, 11421|EURUSD, 11421|AUDUSD, 12567|XAUUSD, 12567|XNGUSD,
  12989|XAUUSD — identical set to the 2026-07-29 re-init. Files exist in BOTH
  loader locations, all n >= 30 (30..331), parse clean.

## Root cause (evidence, not hypothesis)

EX5 build mtimes on T_Live separate the two groups **perfectly**:

| Group | Build dates |
|---|---|
| all 14 LOADED | 2026-07-13 .. 2026-07-17 |
| all 9 unexpected ABSENT | 2026-06-28 / 2026-07-04 |

⇒ The 7 affected EAs (10911, 10919, 10939, 11132, 11421, 12567, 12989) run
**pre-2026-07-13 binaries predating the kill-switch source fix** (MNT-043
recompile debt). Their compiled loader cannot resolve/load the baseline the
current include loads fine. Timing/mtime theories from the 07-29 recon are
superseded: two independent restarts with files present reproduce ABSENT
deterministically on exactly these binaries.

**Consequence:** no restart will arm these 9 sleeves. Closing them requires
recompiled binaries deployed to T_Live via the standing OWNER-gated deploy
workflow (factory build → SHA manifest → OWNER approval → file-side deploy →
re-init), with the recompile→`vintage_stale` evidence doctrine applied.

## Updated coverage ledger

11 armed (pre-restart) → **14 armed now** (ceiling reachable today). Remaining
gap: 9 sleeves blocked on recompile (MNT-043 slice), 10440 pipeline-only,
10513 provenance re-confirm. Sunday session shrinks to: swap capture +
(if approved) recompile deploy + optional Factory-OFF requeue window.
