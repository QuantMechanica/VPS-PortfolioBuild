# MT5 Diagnostic & Recovery Scripts

MQL5 scripts for specific MT5-side incidents. Drag onto a chart in the
affected terminal; read the Experts log.

## `QM_Recover_DWX_Symbols.mq5`

Re-creates the custom DWX symbols after an unclean VPS reboot wipes
`symbols.custom.dat`. The `.tkc` / `.hcc` cache survives the reboot and
re-attaches automatically when the symbol is re-created with the same
name. Origin: 2026-05-22 incident.

- `InpTestOnly = true`  -> EURUSD.DWX only (safe probe).
- `InpTestOnly = false` -> all 40 symbols.

After running, **close the terminal cleanly** (File -> Exit) so the
re-registered definitions persist to `symbols.custom.dat`.

## `QM_Probe_NewsFile.mq5`

Probes `FileOpen` for the news calendar CSV across sandbox / COMMON /
absolute / colon-stripped variants. Reports which path MT5 actually
opens. Diagnosed the 2026-05-23 news-init failure (MT5 5833 rejects
absolute paths with err 5002).

Companion fix:
- News CSVs deployed to `<Common>\Files\`.
- Framework patch in `QM_NewsReadFileBytes` (commit `3a7a2207`) - basename
  + `FILE_COMMON` fallback after the absolute path is refused.

## Compile

```
& "D:\QM\mt5\T1\MetaEditor64.exe" /compile:"<script>.mq5"
```

Then copy the `.ex5` into every terminal's `MQL5\Scripts\` (or just T1
for a one-terminal probe).
