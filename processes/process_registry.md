# Process Registry

## Factory Setup Standards

- MT5 factory terminals `T1`-`T5` must include an install-root `portable.txt` marker file (empty file) to prevent AppData split-brain when launched without explicit `/portable`.

## Build Tooling Paths

- Canonical MetaEditor path for framework compile harnesses: `D:\QM\mt5\T1\MetaEditor64.exe`.
- Reference file for automation and operator checks: `framework/scripts/metaeditor_path.txt`.
- Path discovery note: executable name is `MetaEditor64.exe` (capital `E`), which may be missed by case-sensitive/glob-restricted checks.
