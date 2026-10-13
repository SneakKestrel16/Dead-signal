# Waits for the Godot side to be ready, then injects 10 relative mouse moves of +20 px x.
param([string]$ReadyFile)
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, System.UIntPtr e);'
$deadline = (Get-Date).AddSeconds(20)
while (-not (Test-Path $ReadyFile) -or -not ((Get-Content $ReadyFile) -match 'READY')) {
  if ((Get-Date) -gt $deadline) { Write-Output 'no READY'; exit 1 }
  Start-Sleep -Milliseconds 100
}
for ($i = 0; $i -lt 10; $i++) { [W.U]::mouse_event(1, 20, 0, 0, [System.UIntPtr]::Zero); Start-Sleep -Milliseconds 50 }
Write-Output 'injected 200 px'
