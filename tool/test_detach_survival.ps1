$childPath = Join-Path $env:TEMP "lona-survive-child.ps1"
$childLog = Join-Path $env:TEMP "lona-survive-child.log"
@'
Add-Content -Path "$env:TEMP\lona-survive-child.log" -Value "$(Get-Date -Format o) child start pid=$PID"
Start-Sleep -Seconds 8
Add-Content -Path "$env:TEMP\lona-survive-child.log" -Value "$(Get-Date -Format o) child still alive"
'@ | Set-Content $childPath
Remove-Item $childLog -ErrorAction SilentlyContinue
Start-Process powershell -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$childPath
exit 0
