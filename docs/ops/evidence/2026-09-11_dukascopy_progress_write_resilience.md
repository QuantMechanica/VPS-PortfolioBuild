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
