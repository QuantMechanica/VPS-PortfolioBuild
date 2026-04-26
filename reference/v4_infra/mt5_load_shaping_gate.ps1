[CmdletBinding()]
param(
    [ValidateSet("2T", "3T")]
    [string]$CurrentMode = "2T",

    [double]$MemoryUsedPct = [double]::NaN,
    [double]$DiskFreeGb = [double]::NaN,
    [double]$DiskDropGb10Min = [double]::NaN,
    [double]$HighMemoryMinutes = 0,
    [int]$ConsecutiveHealthyPolls = 0,

    [switch]$CriticalAlertActive,
    [string]$StateFilePath = "Company/Observability/state.json",
    [string]$DiskDrive = "C:"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Try-Get-StateJson {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }
    try {
        return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Try-Get-MemoryUsedPctFromHost {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        return [math]::Round((1 - ($os.FreePhysicalMemory / $os.TotalVisibleMemorySize)) * 100, 2)
    } catch {
        return [double]::NaN
    }
}

function Try-Get-DiskFreeGbFromHost {
    param([string]$Drive)
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive'"
        if ($null -eq $disk) {
            return [double]::NaN
        }
        return [math]::Round(($disk.FreeSpace / 1GB), 2)
    } catch {
        return [double]::NaN
    }
}

$state = Try-Get-StateJson -Path $StateFilePath
$criticalFromInput = $PSBoundParameters.ContainsKey("CriticalAlertActive")
$criticalActive = $false

if ($null -ne $state) {
    if ([double]::IsNaN($MemoryUsedPct)) {
        try {
            $MemoryUsedPct = [double]$state.targets.memory.local_box.used_pct
        } catch {
            $MemoryUsedPct = [double]::NaN
        }
    }

    if ([double]::IsNaN($DiskFreeGb)) {
        try {
            $DiskFreeGb = [double]$state.targets.disk.local_c_drive.free_gb_win32_logicaldisk
        } catch {
            $DiskFreeGb = [double]::NaN
        }
    }

    if (-not $criticalFromInput) {
        try {
            foreach ($alert in $state.active_alerts) {
                if ("$($alert.severity)" -like "critical*") {
                    $criticalActive = $true
                    break
                }
            }
        } catch {
            $criticalActive = $false
        }
    }
}

if ($criticalFromInput) {
    $criticalActive = [bool]$CriticalAlertActive
}

if ([double]::IsNaN($MemoryUsedPct)) {
    $MemoryUsedPct = Try-Get-MemoryUsedPctFromHost
}

if ([double]::IsNaN($DiskFreeGb)) {
    $DiskFreeGb = Try-Get-DiskFreeGbFromHost -Drive $DiskDrive
}

if ([double]::IsNaN($MemoryUsedPct) -or [double]::IsNaN($DiskFreeGb)) {
    throw "Could not determine required metrics (memory_used_pct or disk_free_gb)."
}

$thresholds = [ordered]@{
    entry_memory_max_pct            = 88
    entry_disk_min_gb               = 50
    entry_healthy_polls_min         = 3
    fallback_memory_min_pct         = 92
    fallback_memory_minutes_min     = 6
    fallback_disk_min_gb            = 35
    fallback_disk_drop_gb_10m_min   = 10
}

$entryReady = ($MemoryUsedPct -le $thresholds.entry_memory_max_pct) `
    -and ($DiskFreeGb -ge $thresholds.entry_disk_min_gb) `
    -and (-not $criticalActive) `
    -and ($ConsecutiveHealthyPolls -ge $thresholds.entry_healthy_polls_min)

$fallbackMemory = ($MemoryUsedPct -ge $thresholds.fallback_memory_min_pct) `
    -and ($HighMemoryMinutes -ge $thresholds.fallback_memory_minutes_min)
$fallbackDiskLow = $DiskFreeGb -le $thresholds.fallback_disk_min_gb
$fallbackDiskDrop = (-not [double]::IsNaN($DiskDropGb10Min)) `
    -and ($DiskDropGb10Min -ge $thresholds.fallback_disk_drop_gb_10m_min)
$fallbackCritical = $criticalActive

$reasons = New-Object System.Collections.Generic.List[string]
$recommendation = "stay_2T"

if ($CurrentMode -eq "2T") {
    if ($entryReady) {
        $recommendation = "allow_3T"
        $reasons.Add("3T entry gate passed.")
    } else {
        $recommendation = "stay_2T"
        if ($MemoryUsedPct -gt $thresholds.entry_memory_max_pct) {
            $reasons.Add("Memory used $MemoryUsedPct% is above entry threshold $($thresholds.entry_memory_max_pct)%.")
        }
        if ($DiskFreeGb -lt $thresholds.entry_disk_min_gb) {
            $reasons.Add("Disk free $DiskFreeGb GB is below entry threshold $($thresholds.entry_disk_min_gb) GB.")
        }
        if ($criticalActive) {
            $reasons.Add("Critical alert is active.")
        }
        if ($ConsecutiveHealthyPolls -lt $thresholds.entry_healthy_polls_min) {
            $reasons.Add("Healthy poll count $ConsecutiveHealthyPolls is below required $($thresholds.entry_healthy_polls_min).")
        }
    }
} else {
    if ($fallbackMemory -or $fallbackDiskLow -or $fallbackDiskDrop -or $fallbackCritical) {
        $recommendation = "fallback_to_2T"
        if ($fallbackMemory) {
            $reasons.Add("Memory fallback triggered: $MemoryUsedPct% for $HighMemoryMinutes minutes.")
        }
        if ($fallbackDiskLow) {
            $reasons.Add("Disk fallback triggered: $DiskFreeGb GB <= $($thresholds.fallback_disk_min_gb) GB.")
        }
        if ($fallbackDiskDrop) {
            $reasons.Add("Disk-drop fallback triggered: $DiskDropGb10Min GB drop in 10 minutes.")
        }
        if ($fallbackCritical) {
            $reasons.Add("Critical alert fallback triggered.")
        }
    } else {
        $recommendation = "hold_3T"
        $reasons.Add("No fallback trigger active.")
    }
}

$result = [ordered]@{
    timestamp_local            = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss zzz")
    current_mode               = $CurrentMode
    recommendation             = $recommendation
    metrics                    = [ordered]@{
        memory_used_pct            = $MemoryUsedPct
        disk_free_gb               = $DiskFreeGb
        disk_drop_gb_10m           = if ([double]::IsNaN($DiskDropGb10Min)) { $null } else { $DiskDropGb10Min }
        high_memory_minutes        = $HighMemoryMinutes
        consecutive_healthy_polls  = $ConsecutiveHealthyPolls
        critical_alert_active      = $criticalActive
    }
    thresholds                 = $thresholds
    reasons                    = $reasons
    state_file_path            = $StateFilePath
}

$result | ConvertTo-Json -Depth 6
