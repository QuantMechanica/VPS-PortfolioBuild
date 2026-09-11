# Dukascopy progress-write resilience

Router task: `4fa85eb8-9e6d-435e-bcf2-780c84f9d4d8`.

`common.atomic_write_bytes` now retries a share-locked `os.replace` for up to
30 seconds with bounded jittered backoff and raises `AtomicReplaceError` only
after that period. `download_bi5.py` limits advisory `progress.json` writes to
once per 15 seconds; an exhausted progress write logs at most once per minute
and never interrupts the durable append-only hour ledger or download loop.

Focused verification:

```text
python -m pytest tools/dukascopy/tests -q
24 passed
python -m py_compile tools/dukascopy/common.py tools/dukascopy/download_bi5.py
PASS
```

The existing production downloader was not restarted or modified in memory.
At its next authorized resume-safe relaunch it will pick up this commit.

**RESULT (Q-only):** Q-DUKASCOPY is REVIEW — the progress-share-lock repair is
implemented and tested; the active production process remains untouched.

**Crash timestamp:** 2026-09-11T04:35Z, `PermissionError [WinError 5]` in
`atomic_write_text` -> `atomic_write_bytes` -> `os.replace(progress.json.tmp,
progress.json)` (share-locked reader), in
`D:/QM/reports/dukascopy/backfill/20260909T191800Z_hardened/download.log`.
**Fix commit:** `fe7cc4ce09e5c492153b125f4967bd530fd5ef77`.
**Relaunch instruction:** the process that crash-relaunched at 05:11Z (PID
11056, `resume`d from the hour ledger 7,778 -> 11,693) and the one running now
(PID confirmed via `progress.json.started_at_utc=2026-09-11T05:22:13.175Z`,
i.e. started *before* this commit) both still run the pre-fix binary — no
action needed on them; they resume correctly from `hour_ledger.jsonl` on any
crash regardless. The retry/backoff hardening takes effect only once this
process is next stopped and the identical `download_bi5.py` resume command is
relaunched (no flag change required — same `--out` root, same symbol list,
resumes via the ledger as always). Do not restart the currently running
process solely to pick up this fix; let it continue and apply automatically
at its next natural relaunch (e.g. after a future crash or an explicit,
separately authorized stop).
