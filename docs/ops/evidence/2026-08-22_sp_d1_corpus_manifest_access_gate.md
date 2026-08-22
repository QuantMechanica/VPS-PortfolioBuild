# SP-D1 content-addressed corpus manifest — access gate

Date: 2026-08-22  
Router task: `0fb2edcb-7411-4323-9422-e4fb0fd9adc2`  
Verdict: **BLOCKED — the per-user Google Drive archive is not visible to this headless task**

## Measured blocker

The requested 130-file corpus lives under the `G:` Google Drive mount. In this headless orchestration session:

- `Get-PSDrive G` returns no drive;
- `Test-Path 'G:/My Drive/QuantMechanica - Company Reference/12 ToDo/_INDEX.md'` returns `False`;
- direct `cmd /c dir` access to the supplied archive path returns `Access is denied`;
- the sanctioned `QM_GoogleDrive_AtLogon` task was started once, returned result `0`, and GoogleDriveFS processes are alive in interactive session 1, but `G:` remains unavailable in the headless session;
- the headless filesystem provider exposes only `C:`, `D:`, and `Temp:`.

This is the known per-user DriveFS boundary: process liveness does not make its interactive-session drive letter readable from the scheduler's headless security context.

## Why no partial manifest was emitted

The acceptance contract requires 130/130 file identities, 127 PDF-to-ledger bindings, and three MQ5 files classified `RAW_UNTRUSTED`. Without readable file bytes, SHA-256, size, media type, relative path, and coverage cannot be measured. A row set inferred from titles or the farm database would not be content-addressed and would create false provenance.

The canonical farm database is readable in immutable mode and currently contains 117 `sources` rows, including six `local_archive` rows (five blocked, one done). That table is not a substitute for the required 130-file archive census, and no ingestion or card generation was triggered.

## Required unblock

Run the manifest collector in the same interactive `qm-admin` session/security context that owns the DriveFS mount, or expose the exact corpus through a read-only machine-visible path. The collector must then bind existing ledger rows only; it must not enqueue source research, reserve EA IDs, or create cards. The output belongs in canonical evidence and should include a strict coverage assertion:

```text
files_total=130
pdf_total=127
mq5_total=3
ledger_bound_pdf=127
raw_untrusted_mq5=3
sha256_missing=0
```

No archive file, database row, source status, card, or queue item was changed. The only recovery action was invoking the already-sanctioned DriveFS at-logon scheduled task once; it did not make `G:` visible to this headless process.
