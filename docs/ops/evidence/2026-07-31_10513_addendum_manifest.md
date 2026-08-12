# QM5_10513 unsigned addendum to the KS vintage Sunday packet

**Status:** UNSIGNED — NO DEPLOY AUTHORITY

**Prepared:** 2026-07-31

**Router task:** `626f0d57-ceac-40c4-8687-c8192c625650`

**Reviewer required:** Claude

This addendum authorizes nothing while the signature fields remain empty. It performs no rebuild, T_Live write, terminal-local baseline write, terminal re-init, manual terminal start, AutoTrading change, or pipeline mutation. After Claude review and a separate OWNER signature, it would add one existing canonical binary and one live identity to the Stage-3 Sunday packet: seven binary targets become eight, and the `KS_BASELINE_LOADED` gate becomes 10/10 instead of 9/9.

The machine-readable companion is [`2026-07-31_10513_addendum_manifest.json`](2026-07-31_10513_addendum_manifest.json), SHA-256 `9ae687d60355141caa20cca23e6dda4ea7b530db3df6754bfb8a2e0ded609c45`.

## Decision presented to OWNER

The intended swap is the old June-28 T_Live EX5 for the already-built July-13 canonical EX5. It is not a rebuild and it is not a narrow baseline-path patch. The exact July-13 bytes are also the executable identity observed by the clean Q10 PASS used to generate the reviewed baseline.

| Item | Path / value | SHA-256 |
|---|---|---|
| canonical source EX5 | `C:\QM\repo\framework\EAs\QM5_10513_mql5-ichimoku\QM5_10513_mql5-ichimoku.ex5` (324,966 bytes) | `04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898` |
| canonical binary commit | `cf2264bb09f1761b5340381647b0c5bb0144235b` — July-13 true rebuild wave | Git blob reproduces the same SHA-256 |
| T_Live target / rollback preimage | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_10513_mql5-ichimoku.ex5` (286,118 bytes; 2026-06-28 07:11:02Z) | `518a9b37503e0932b2dff6efbd67458484dbef74ab045c0181f85bee583b6d2f` |
| Q10 aggregate | `D:\QM\reports\pipeline\QM5_10513\Q10\XAUUSD_DWX\aggregate.json` | `166704e04b11bb8023a7760a8e9d8d395281494c03c3654596d84fe8af798def` |
| Q10 native summary | `D:\QM\reports\pipeline\QM5_10513\20260725_163009\summary.json` | `7e8a4f97417220a7ad5d29531a090a5fc9d7b165d7f6a388b30ee89386b8425a` |
| Q10 work item | `297c0127-7a8e-4bcd-bbbb-c4a57e823477`, `done/PASS` | observed EX5 `04b62af...63898` |

The Q10 summary binds source and deployed tester EX5 to `04b62af...63898`, and its binary stayed stable through the run. This is executable provenance for the no-rebuild proposal.

There is an important source caveat. The MQ5 blob at the July-13 build commit hashes to `bd400ee29f6c63a593e880cda31591238b898cb5317d7ba4f614d08ee9cfa53c`; the later current MQ5 hashes to `b8508e053bf0a335dcea67c8315e635b168649b14e0b7bca906242cc811dfc99`. This addendum therefore binds only the existing EX5 bytes and does not claim that the later current MQ5 or current include closure produced them. No compile or closure provenance is invented.

## Tenth identity and baseline placement

| EA | symbol / timeframe | slot / magic | chart | preset / SHA-256 |
|---:|---|---|---|---|
| 10513 | XAUUSD / D1 (`XAUUSD.DWX` registry identity) | 3 / `105130003` | `DarwinexZero_V2_LiveOps/chart15.chr`; `cb905432...b8c4d8` | `19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set`; `7d15a3491465b916e7e5a0f2ef36212f76f43fde6fc186586cde542431080408` |

The registry has one active EA row and one active exact magic row for `10513 / XAUUSD.DWX / slot 3 / 105130003`. The chart independently resolves the same EA, XAUUSD, D1, and slot.

Both loader aliases are 1,680 bytes, file SHA-256 `edf01c12b79642f1277326f0977c77e25df5c5a63747501044875055cce1317e`, and internal distribution hash `5588dca1f62283a0ca4b32daccd5ec27a09acf4a949fd880446e9adfe5fdff9b`:

| Alias | `D:\QM\data\baselines` | FILE_COMMON | T_Live terminal-local |
|---|---|---|---|
| `QM5_10513_XAUUSD_DWX.json` | present / match | present / match | absent — Sunday step |
| `QM5_10513_XAUUSD.json` | present / match | present / match | absent — Sunday step |

The fileside placement receipt is `D:\QM\reports\state\10513_baseline_fileside_deploy_20260731.json`, SHA-256 `b5f9c2f2f1e15135113289361f9750fc6853c3b96865a68714528d37d0767eb8`. The terminal-local copies remain deliberately deferred.

## Position rider — corrected at packet time

The router payload correctly required an explicit warning because QM5_10513 had an open short, ticket `3169829687`, opened at `2026-07-29T22:01:00.765Z`; the EA rejected a duplicate against that position at `2026-07-31T13:09:48.656Z`.

That claim became stale before this addendum was drafted. The same immutable EA log records `FRIDAY_CLOSE`, `closed=1`, at `2026-07-31T17:59:56.781Z`. The read-only live-book pulse generated at `2026-07-31T22:00:01Z` reports `current_position_count=0` and `position_exposed=false`; the later terminal sync at `22:01:21.124Z` also reports zero positions and four account-wide pending orders. The pulse snapshot SHA-256 is `c4a5a9b04e59fe1a4f3cbb3e32a11d2075871dbb08b56723b583d28ce33ded95`.

OWNER must still treat position/order exposure as a live precondition, not as a permanently cleared fact. Immediately before any copy, re-read the authoritative account state. Any QM5_10513 position or pending-order management consequence requires explicit OWNER acceptance; otherwise stop.

## Behavioral riders — explicit acceptance required

This is not a KS-only change. Between the June-28 binary-wave commit and the July-13 build pin, 20 framework include files changed by 2,192 insertions and 84 deletions. The proposed executable therefore carries the shared framework changes present at its pin, including kill-switch path/persistence behavior, news mapping and gating, risk sizing and caps, stop/order hardening, trade context, and telemetry/equity-stream behavior. OWNER acceptance is acceptance of the complete `04b62af...63898` binary, not merely its ability to load a baseline.

The July-13 EA source did not yet call `QM_FrameworkDeclareExecutionContract`. A rebuild is forbidden by this task. Consequently the existing nine Stage-3 rows retain their complete verification contract, while the tenth row extends the live-only `KS_BASELINE_LOADED` cardinality gate and requires `INIT_OK`, `NEWS_CALENDAR_LOADED`, exact identity, exact loaded baseline hash, and exact binary/preset hashes. It must not fabricate an `EXECUTION_CONTRACT` event for this pin.

## Sunday runbook addendum — execute only after new signatures

Run the base packet's seven-file preflight first. Append the following one-EA operation before the controlled re-init. The placeholders deliberately fail closed while this packet is unsigned.

```powershell
$ownerAddendumDecision = 'REPLACE_WITH_EXACT_SIGNED_OWNER_WORDING'
if ($ownerAddendumDecision -eq 'REPLACE_WITH_EXACT_SIGNED_OWNER_WORDING') {
    throw 'QM5_10513 addendum is unsigned; no deploy authority'
}

$addendumPath = 'C:\QM\repo\docs\ops\evidence\2026-07-31_10513_addendum_manifest.json'
$expectedAddendumSha = '9ae687d60355141caa20cca23e6dda4ea7b530db3df6754bfb8a2e0ded609c45'
$sourceEx5 = 'C:\QM\repo\framework\EAs\QM5_10513_mql5-ichimoku\QM5_10513_mql5-ichimoku.ex5'
$liveTarget = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_10513_mql5-ichimoku.ex5'
$preset = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set'
$seedRoot = 'D:\QM\data\baselines'
$commonRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files\QM\baselines'
$terminalRoot = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines'
$rollbackRoot = 'C:\QM\deploy\KSRecompile_20260802_386151841\preimages_addendum_10513'
$baselineSha = 'edf01c12b79642f1277326f0977c77e25df5c5a63747501044875055cce1317e'
$aliases = 'QM5_10513_XAUUSD_DWX.json','QM5_10513_XAUUSD.json'

function Assert-Sha256([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA256 mismatch: $Path expected=$Expected actual=$actual"
    }
}

Assert-Sha256 $addendumPath $expectedAddendumSha
Assert-Sha256 $sourceEx5 '04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898'
Assert-Sha256 $liveTarget '518a9b37503e0932b2dff6efbd67458484dbef74ab045c0181f85bee583b6d2f'
Assert-Sha256 $preset '7d15a3491465b916e7e5a0f2ef36212f76f43fde6fc186586cde542431080408'

foreach ($alias in $aliases) {
    Assert-Sha256 (Join-Path $seedRoot $alias) $baselineSha
    Assert-Sha256 (Join-Path $commonRoot $alias) $baselineSha
    $terminalPath = Join-Path $terminalRoot $alias
    if (Test-Path -LiteralPath $terminalPath) {
        throw "Unexpected terminal-local baseline preimage; stop for fresh review: $terminalPath"
    }
}

# Before continuing, attach a fresh authoritative position/order preflight
# proving the OWNER has accepted any QM5_10513 exposure consequence.
$positionPreflightAcceptedByOwner = $false
if (-not $positionPreflightAcceptedByOwner) { throw 'Fresh OWNER exposure acceptance missing' }

if (Test-Path -LiteralPath $rollbackRoot) { throw "Rollback directory already exists: $rollbackRoot" }
New-Item -ItemType Directory -Path $rollbackRoot | Out-Null
$backup = Join-Path $rollbackRoot 'QM5_10513_mql5-ichimoku.ex5'
Copy-Item -LiteralPath $liveTarget -Destination $backup
Assert-Sha256 $backup '518a9b37503e0932b2dff6efbd67458484dbef74ab045c0181f85bee583b6d2f'

foreach ($alias in $aliases) {
    Copy-Item -LiteralPath (Join-Path $seedRoot $alias) -Destination (Join-Path $terminalRoot $alias)
    Assert-Sha256 (Join-Path $terminalRoot $alias) $baselineSha
}

Copy-Item -LiteralPath $sourceEx5 -Destination $liveTarget -Force
Assert-Sha256 $liveTarget '04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898'
$deploymentEpochUtc = [DateTimeOffset]::UtcNow
$deploymentEpochUtc.ToString('o')
```

Stop after the printed epoch. OWNER performs the standing controlled T_Live re-init. Never start `terminal64.exe` manually and never toggle AutoTrading. If news is stale, refresh `D:\QM\data\news_calendar` and its FILE_COMMON copy; never raise `qm_news_stale_max_hours` above 336.

### First post-deploy 10/10 gate

Run the base packet's nine-row JSON verification unchanged, then add this tenth row:

```powershell
$row = [pscustomobject]@{
    ea=10513; symbol='XAUUSD'; tf='D1'; magic=105130003
    baseline='QM5_10513_XAUUSD.json'
    file_sha='edf01c12b79642f1277326f0977c77e25df5c5a63747501044875055cce1317e'
}
$log = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_10513_ea-10513.log'
$events = Get-Content -LiteralPath $log | ForEach-Object {
    try { $_ | ConvertFrom-Json -ErrorAction Stop } catch { }
}
$scope = @($events | Where-Object {
    [DateTimeOffset]::Parse([string]$_.ts_utc) -ge $deploymentEpochUtc -and
    [int]$_.ea_id -eq $row.ea -and [string]$_.symbol -eq $row.symbol -and
    [string]$_.tf -eq $row.tf -and [long]$_.magic -eq $row.magic
})
$loaded = @($scope | Where-Object event -eq 'KS_BASELINE_LOADED')
$absent = @($scope | Where-Object event -eq 'KS_BASELINE_ABSENT')
$init = @($scope | Where-Object event -eq 'INIT_OK')
$news = @($scope | Where-Object event -eq 'NEWS_CALENDAR_LOADED')
$baselinePath = Join-Path 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines' $row.baseline
Assert-Sha256 $baselinePath $row.file_sha
$baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json
$latestLoaded = $loaded | Sort-Object { [DateTimeOffset]::Parse([string]$_.ts_utc) } | Select-Object -Last 1
$eventHash = if ($null -eq $latestLoaded) { '' } else { ([string]$latestLoaded.payload.hash).ToLowerInvariant() }
$baselineHash = ([string]$baseline.hash).ToLowerInvariant()
$ok10513 = $loaded.Count -ge 1 -and $absent.Count -eq 0 -and
           $init.Count -ge 1 -and $news.Count -ge 1 -and
           $eventHash -eq $baselineHash
if (-not $ok10513) { throw 'QM5_10513 POST-DEPLOY GATE FAILED' }
Assert-Sha256 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_10513_mql5-ichimoku.ex5' '04b62af28c6466e01741aacaa915d9a68714cd7c23288ae277615ae068d63898'
Assert-Sha256 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set' '7d15a3491465b916e7e5a0f2ef36212f76f43fde6fc186586cde542431080408'
```

The authoritative result is ten PASS rows: the original nine under the base contract plus this exact tenth identity. Any mismatch invokes the stop decision; it is not a pipeline verdict.

### Rollback delta — separate written OWNER authority required

Restore the verified `518a9b...b6d2f` EX5 preimage from `preimages_addendum_10513`, verify it, and remove only the two newly created terminal-local baseline aliases after confirming each still hashes to `edf01c12...1317e`. Do not edit the seed or FILE_COMMON copies. Then stop for the OWNER-controlled re-init and repeat read-only verification. Any unexpected terminal-local preimage or changed hash requires fresh review instead of deletion.

## Verification and non-action proof

- Canonical EX5 SHA/size matches both the working-tree file and the exact `cf2264bb` Git blob.
- Live EX5 preimage SHA/size/mtime captured read-only and differs exactly as expected.
- Q10 aggregate and summary bind the canonical EX5; baseline pair verifies in seed and FILE_COMMON.
- Terminal-local baseline aliases are absent; no copy occurred.
- EA registry, magic registry, chart and preset resolve the one exact identity.
- Position warning was reconciled against later read-only evidence and remains a mandatory Sunday preflight.
- No T_Live file, terminal, chart, AutoTrading state, registry, baseline, Factory row, or pipeline verdict was changed.

## Empty review and signature fields

**Claude review wording:** APPROVED. Independently verified: addendum JSON SHA
`9ae687d6…`, canonical EX5 == exact `cf2264bb` git blob (`04b62af2…`), live
preset hash match. The two honest caveats are accepted as stated: (1) EX5-only
executable provenance (Q10-run-bound), no invented compile lineage; (2) no
EXECUTION_CONTRACT event for this pin — the tenth gate row correctly omits it.
Behavioral riders (full June-28→July-13 framework delta) and the mandatory
fresh position/order preflight are properly OWNER-facing. Deploy authority
arises only with the OWNER signature below.

**Claude reviewer/date:** Claude, 2026-07-31 ~22:45Z

**OWNER decision wording:** „klar akzeptier ich das, somit freigegeben"
(Chat, 2026-08-01 vormittags — nach Vorlage der Mitfahrer, der EX5-only-
Provenienz-Fußnote und des Positions-Preflights; transkribiert durch Claude)

**OWNER name/signature:** OWNER (Chat-Signatur 2026-08-01)

**OWNER date/time:** 2026-08-01, ~09:50 lokal

**Approved Sunday window:** identisch mit dem Basis-Paket — 2026-08-02,
marktgeschlossenes Fenster; Deploy als 8. Datei im §1-Ablauf, Gate 10/10.

**Separate OWNER rollback authorization wording:**

**Separate OWNER rollback signature/date:**
