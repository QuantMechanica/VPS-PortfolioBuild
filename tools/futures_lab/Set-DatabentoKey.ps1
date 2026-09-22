[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security
$privateRoot = 'D:\QM\futures_lab\private'
$keyPath = Join-Path $privateRoot 'databento.dpapi'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()

function Assert-NoReparse([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'Reparse credential path refused'
        }
        $parent = [IO.Directory]::GetParent($current)
        $current = if ($parent) { $parent.FullName } else { $null }
    }
}

Assert-NoReparse $privateRoot
if (Test-Path -LiteralPath $keyPath) {
    [void][Windows.Forms.MessageBox]::Show('Ein lokaler Schluessel ist bereits eingerichtet. Dieses Fenster ersetzt ihn nicht.','QuantMechanica')
    exit 0
}
$form = New-Object Windows.Forms.Form
$form.Text = 'QuantMechanica - Databento API-Key lokal speichern'
$form.Size = New-Object Drawing.Size(630,270)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object Windows.Forms.Label
$label.Location = New-Object Drawing.Point(20,15)
$label.Size = New-Object Drawing.Size(580,75)
$label.Text = "API-Key aus dem Databento-Portal hier eingeben.`r`nVerschluesselt fuer Windows-Benutzer $($identity.Name).`r`nDieses Fenster sendet nichts an Databento und kauft keine Daten."
$field = New-Object Windows.Forms.TextBox
$field.Location = New-Object Drawing.Point(20,95)
$field.Size = New-Object Drawing.Size(570,25)
$field.UseSystemPasswordChar = $true
$field.MaxLength = 128
$save = New-Object Windows.Forms.Button
$save.Text = 'Lokal speichern'
$save.Location = New-Object Drawing.Point(20,145)
$save.Size = New-Object Drawing.Size(170,32)
$cancel = New-Object Windows.Forms.Button
$cancel.Text = 'Abbrechen'
$cancel.Location = New-Object Drawing.Point(205,145)
$cancel.Size = New-Object Drawing.Size(120,32)
$cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $cancel
$form.AcceptButton = $save
$save.Add_Click({
    $rawBytes = $null
    try {
        $candidate = $field.Text.Trim()
        if ($candidate -cnotmatch '^db-[A-Za-z0-9_-]{29}$') {
            [void][Windows.Forms.MessageBox]::Show('Erwartet wird ein 32-stelliger Databento-Key mit db- am Anfang.','Format pruefen')
            return
        }
        Assert-NoReparse $privateRoot
        if (-not (Test-Path -LiteralPath $privateRoot)) { [void][IO.Directory]::CreateDirectory($privateRoot) }
        $acl = New-Object Security.AccessControl.DirectorySecurity
        $acl.SetOwner($identity.User)
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($sid in @($identity.User, (New-Object Security.Principal.SecurityIdentifier('S-1-5-18')))) {
            $rule = New-Object Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
            [void]$acl.AddAccessRule($rule)
        }
        Set-Acl -LiteralPath $privateRoot -AclObject $acl
        Assert-NoReparse $keyPath
        $rawBytes = [Text.Encoding]::UTF8.GetBytes($candidate)
        $entropy = [Text.Encoding]::UTF8.GetBytes('QM.FuturesLab.Databento.v1')
        $blob = [Security.Cryptography.ProtectedData]::Protect($rawBytes, $entropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $stream = [IO.File]::Open($keyPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $stream.Write($blob, 0, $blob.Length); $stream.Flush($true) } finally { $stream.Dispose() }
        $field.Clear()
        $candidate = $null
        [void][Windows.Forms.MessageBox]::Show('Verschluesselt lokal gespeichert. Im Chat reicht: Schluessel lokal gespeichert.','QuantMechanica')
        $form.DialogResult = [Windows.Forms.DialogResult]::OK
        $form.Close()
    } catch {
        [void][Windows.Forms.MessageBox]::Show('Speichern fehlgeschlagen. Kein Schluessel wird ausgegeben. Codex kann Pfad und Berechtigungen pruefen.','QuantMechanica')
    } finally {
        if ($null -ne $rawBytes) { [Array]::Clear($rawBytes,0,$rawBytes.Length) }
    }
})
$form.Controls.AddRange(@($label,$field,$save,$cancel))
[void]$form.ShowDialog()
$field.Clear()
$form.Dispose()
