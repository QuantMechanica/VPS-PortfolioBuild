# One-shot SYSTEM probe: does the LSA autologon secret exist?
# (HKLM\SECURITY is readable only by SYSTEM - admin contexts always see $false.)
$result = @{}
try {
    $k = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Default').OpenSubKey('SECURITY\Policy\Secrets\DefaultPassword')
    $result.secret_present = ($null -ne $k)
} catch {
    $result.secret_present = $false
    $result.error = $_.Exception.Message
}
$result.autoadmin = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).AutoAdminLogon -eq '1')
$result.default_user = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
$result.probed_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$result.context = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$result | ConvertTo-Json -Compress | Set-Content -Path 'D:\QM\reports\state\autologon_secret_probe.json' -Encoding UTF8
