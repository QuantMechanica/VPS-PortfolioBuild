# =====================================================================
#  QuantMechanica - run_in_console_session.ps1
#  Launch a process INTO the active console (autologon) session from a
#  SYSTEM/session-0 context. This is the primitive that lets the headless
#  SYSTEM FactoryWatchdog respawn MT5 terminal_worker daemons back into
#  OWNER's interactive desktop session (visible-mode) even when the RDP
#  session is DISCONNECTED.
#
#  Mechanism (standard Win32):
#    WTSGetActiveConsoleSessionId -> the autologon console session id
#    WTSQueryUserToken            -> that session's user token (needs SeTcb;
#                                    SYSTEM has it; a disconnected logged-on
#                                    session still yields a valid token)
#    DuplicateTokenEx + CreateEnvironmentBlock + CreateProcessAsUser
#    (lpDesktop = winsta0\default) -> process lands on the interactive desktop
#
#  MUST run as SYSTEM (LocalSystem). Returns exit 0 on launch success.
#  Usage:
#    powershell -File run_in_console_session.ps1 -Exe "C:\...\python.exe" `
#               -Arguments '"C:\QM\repo\...\start_terminal_workers.py" --dedupe' `
#               -WorkDir "C:\QM\repo"
# =====================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Arguments = "",
    [string]$WorkDir = "C:\QM\repo",
    [string]$TargetUser = ""   # default: autologon DefaultUserName
)
$ErrorActionPreference = 'Stop'

if (-not $TargetUser) {
    $TargetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
    if (-not $TargetUser) { $TargetUser = 'qm-admin' }
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace QM {
    [StructLayout(LayoutKind.Sequential)]
    public struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX; public int dwY; public int dwXSize; public int dwYSize;
        public int dwXCountChars; public int dwYCountChars; public int dwFillAttribute; public int dwFlags;
        public short wShowWindow; public short cbReserved2; public IntPtr lpReserved2;
        public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }

    [StructLayout(LayoutKind.Sequential)]
    public struct WTS_SESSION_INFO {
        public uint SessionID;
        [MarshalAs(UnmanagedType.LPStr)] public string pWinStationName;
        public int State;
    }

    public static class Native {
        [DllImport("kernel32.dll")] public static extern uint WTSGetActiveConsoleSessionId();
        [DllImport("wtsapi32.dll", SetLastError=true)] public static extern bool WTSQueryUserToken(uint SessionId, out IntPtr phToken);
        [DllImport("wtsapi32.dll", SetLastError=true)] public static extern bool WTSEnumerateSessions(IntPtr hServer, int Reserved, int Version, out IntPtr ppSessionInfo, out int pCount);
        [DllImport("wtsapi32.dll")] public static extern void WTSFreeMemory(IntPtr pMemory);
        [DllImport("wtsapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool WTSQuerySessionInformationW(IntPtr hServer, uint SessionId, int WTSInfoClass, out IntPtr ppBuffer, out int pBytesReturned);

        // Find the session id where the given user is logged on (Active preferred, else Disconnected).
        // Returns 0xFFFFFFFF if not found. Skips session 0.
        public static uint FindUserSession(string user) {
            IntPtr pInfo; int count;
            if (!WTSEnumerateSessions(IntPtr.Zero, 0, 1, out pInfo, out count)) return 0xFFFFFFFF;
            uint found = 0xFFFFFFFF;
            try {
                int sz = Marshal.SizeOf(typeof(WTS_SESSION_INFO));
                long cur = pInfo.ToInt64();
                for (int i = 0; i < count; i++) {
                    WTS_SESSION_INFO si = (WTS_SESSION_INFO)Marshal.PtrToStructure((IntPtr)cur, typeof(WTS_SESSION_INFO));
                    cur += sz;
                    if (si.SessionID == 0) continue;
                    IntPtr buf; int bytes;
                    if (WTSQuerySessionInformationW(IntPtr.Zero, si.SessionID, 5 /*WTSUserName*/, out buf, out bytes)) {
                        string uname = Marshal.PtrToStringUni(buf);
                        WTSFreeMemory(buf);
                        if (!string.IsNullOrEmpty(uname) && string.Equals(uname, user, StringComparison.OrdinalIgnoreCase)) {
                            found = si.SessionID;
                            if (si.State == 0) break; // 0 = WTSActive, prefer it
                        }
                    }
                }
            } finally { WTSFreeMemory(pInfo); }
            return found;
        }
        [DllImport("advapi32.dll", SetLastError=true)] public static extern bool DuplicateTokenEx(IntPtr hExistingToken, uint dwDesiredAccess, IntPtr lpTokenAttributes, int ImpersonationLevel, int TokenType, out IntPtr phNewToken);
        [DllImport("userenv.dll", SetLastError=true)] public static extern bool CreateEnvironmentBlock(out IntPtr lpEnvironment, IntPtr hToken, bool bInherit);
        [DllImport("userenv.dll", SetLastError=true)] public static extern bool DestroyEnvironmentBlock(IntPtr lpEnvironment);
        [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)] public static extern bool CreateProcessAsUser(
            IntPtr hToken, string lpApplicationName, string lpCommandLine,
            IntPtr lpProcessAttributes, IntPtr lpThreadAttributes, bool bInheritHandles,
            uint dwCreationFlags, IntPtr lpEnvironment, string lpCurrentDirectory,
            ref STARTUPINFO lpStartupInfo, out PROCESS_INFORMATION lpProcessInformation);
        [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr hObject);
    }
}
"@

$CREATE_UNICODE_ENVIRONMENT = 0x00000400
$CREATE_NO_WINDOW = 0x08000000
$TOKEN_ALL = 0xF01FF
$SecurityImpersonation = 2
$TokenPrimary = 1

$sid = [QM.Native]::FindUserSession($TargetUser)
if ($sid -eq 0xFFFFFFFF) { Write-Error "no logged-on session for user '$TargetUser' (autologon session absent?)"; exit 2 }

$hTok = [IntPtr]::Zero
if (-not [QM.Native]::WTSQueryUserToken($sid, [ref]$hTok)) {
    Write-Error "WTSQueryUserToken failed (need SYSTEM/SeTcb): $([ComponentModel.Win32Exception]::new([Runtime.InteropServices.Marshal]::GetLastWin32Error()).Message)"; exit 3
}
$hDup = [IntPtr]::Zero
if (-not [QM.Native]::DuplicateTokenEx($hTok, $TOKEN_ALL, [IntPtr]::Zero, $SecurityImpersonation, $TokenPrimary, [ref]$hDup)) {
    Write-Error "DuplicateTokenEx failed"; exit 4
}
$env = [IntPtr]::Zero
[void][QM.Native]::CreateEnvironmentBlock([ref]$env, $hDup, $false)

$si = New-Object QM.STARTUPINFO
$si.cb = [Runtime.InteropServices.Marshal]::SizeOf($si)
$si.lpDesktop = "winsta0\default"
$pi = New-Object QM.PROCESS_INFORMATION

# resolve exe to a full path (CreateProcessAsUser does not search PATH reliably)
$exeFull = $Exe
if (-not (Test-Path -LiteralPath $exeFull)) {
    $cmd = Get-Command $Exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $exeFull = $cmd.Source }
}
$cmdline = '"' + $exeFull + '"'
if ($Arguments) { $cmdline += ' ' + $Arguments }

$flags = $CREATE_UNICODE_ENVIRONMENT -bor $CREATE_NO_WINDOW
$ok = [QM.Native]::CreateProcessAsUser($hDup, $exeFull, $cmdline, [IntPtr]::Zero, [IntPtr]::Zero, $false, $flags, $env, $WorkDir, [ref]$si, [ref]$pi)
$err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

if ($env -ne [IntPtr]::Zero) { [void][QM.Native]::DestroyEnvironmentBlock($env) }
if ($hDup -ne [IntPtr]::Zero) { [void][QM.Native]::CloseHandle($hDup) }
if ($hTok -ne [IntPtr]::Zero) { [void][QM.Native]::CloseHandle($hTok) }

if ($ok) {
    if ($pi.hProcess -ne [IntPtr]::Zero) { [void][QM.Native]::CloseHandle($pi.hProcess) }
    if ($pi.hThread  -ne [IntPtr]::Zero) { [void][QM.Native]::CloseHandle($pi.hThread) }
    Write-Output "LAUNCHED pid=$($pi.dwProcessId) into console session $sid : $cmdline"
    exit 0
} else {
    Write-Error "CreateProcessAsUser failed ($err): $([ComponentModel.Win32Exception]::new($err).Message)"; exit 5
}
