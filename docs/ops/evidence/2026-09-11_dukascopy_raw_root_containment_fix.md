# Dukascopy raw-root containment normalization

Date: 2026-09-11
Router task: `ff5cc3b9-b254-4223-9f3e-e22a3c6f7300`

`tools/dukascopy/download_bi5.py` now resolves `raw_root` once at setup, the
same way it resolves each destination, before its containment comparison. The
check remains fail-closed: a resolved destination outside `raw_root` still
raises `ValueError`; no retry, backoff, rate limit, manifest, or ledger behavior
changed.

Focused verification:

```text
python -m pytest tools/dukascopy/tests/test_download_bi5_hardening.py \
  tools/dukascopy/tests/test_dukascopy_backfill.py -q
23 passed
```

The new regression uses equally extended-prefix Windows paths for the valid
case and a separate escaping path for the negative case. It does not restart
the production downloader or change any download state.
