[CmdletBinding()]
param([switch]$Apply,
      [string]$EvidenceDir = 'D:\QM\reports\maintenance\factory_repair_20260908')
$ErrorActionPreference = 'Stop'
$name = 'QM_StrategyFarm_PumpMaintenance_Hourly'
$task = Get-ScheduledTask -TaskName $name
if ($task.State -eq 'Running') { throw 'Wait for the current maintenance run before changing its trigger.' }
$before = Export-ScheduledTask -TaskName $name
[xml]$xml = $before
$ns = New-Object Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('t', $xml.DocumentElement.NamespaceURI)
$intervals = @($xml.SelectNodes('//t:Triggers/*/t:Repetition/t:Interval', $ns))
if ($intervals.Count -ne 1) { throw 'Expected exactly one repeating trigger.' }
$old = $intervals[0].InnerText
if (-not $Apply) {
    [ordered]@{ task=$name; old_interval=$old; new_interval='PT1H'; apply=$false } | ConvertTo-Json
    exit 0
}
if (Test-Path -LiteralPath 'D:\QM\strategy_farm\state\FACTORY_OFF.flag') { throw 'Factory is OFF.' }
New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
$stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$backup = Join-Path $EvidenceDir "maintenance_task_before_$stamp.xml"
[IO.File]::WriteAllText($backup, $before)
$intervals[0].InnerText = 'PT1H'
Register-ScheduledTask -TaskName $name -Xml $xml.OuterXml -Force | Out-Null
[xml]$after = Export-ScheduledTask -TaskName $name
$afterNs = New-Object Xml.XmlNamespaceManager($after.NameTable)
$afterNs.AddNamespace('t', $after.DocumentElement.NamespaceURI)
$verified = $after.SelectSingleNode('//t:Triggers/*/t:Repetition/t:Interval', $afterNs).InnerText
if ($verified -ne 'PT1H') { throw 'Trigger verification failed.' }
$receipt = [ordered]@{ task=$name; old_interval=$old; new_interval=$verified; backup=$backup;
    at_utc=[datetime]::UtcNow.ToString('o'); actions_and_settings_preserved=$true }
$json = $receipt | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $EvidenceDir 'backup_schedule_receipt.json'), $json)
$json
