# Windows Repair Toolkit v1.0
# Targeted Windows 10 22H2 service configuration repair.
#Requires -Version 5.1
#Requires -RunAsAdministrator
param([ValidateSet('Check','Repair','Integrity')][string]$Mode='Check')
$ErrorActionPreference='Stop'
$root=Join-Path $env:ProgramData ('WindowsRepairToolkit\'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $root -Force | Out-Null
Start-Transcript -Path (Join-Path $root 'report.txt') | Out-Null
$failed=$false
try {
 $os=Get-CimInstance Win32_OperatingSystem
 $os | Select Caption,Version,BuildNumber,OSArchitecture | Format-List
 $supported=($os.BuildNumber -eq '19045' -and [Environment]::Is64BitProcess -and $os.ProductType -eq 1)
 $spec=@(
 @{Name='DoSvc';Dll='dosvc.dll';Group='NetworkService';Main=$null},
 @{Name='UsoSvc';Dll='usosvc.dll';Group='netsvcs';Main=$null},
 @{Name='wuauserv';Dll='wuaueng.dll';Group='netsvcs';Main='WUServiceMain'}
 )
 if($Mode -eq 'Repair' -and -not $supported){throw 'Automatic registry repair is restricted to 64-bit PowerShell on Windows 10 build 19045.'}
 if($Mode -eq 'Repair'){
  Write-Host 'Repair adds missing known registry values and attempts to start the three services. No existing values are overwritten.'
  if((Read-Host 'Type REPAIR to proceed') -cne 'REPAIR'){throw 'Cancelled by user.'}
 }
 foreach($s in $spec){
  try {
   $base='HKLM:\SYSTEM\CurrentControlSet\Services\'+$s.Name
   $p=Join-Path $base 'Parameters'
   $svc=Get-Service -Name $s.Name
   $cfg=Get-ItemProperty $base
   $dll=Join-Path $env:SystemRoot ('System32\'+$s.Dll)
   $sig=Get-AuthenticodeSignature $dll
   $v=Get-ItemProperty $p -ErrorAction SilentlyContinue
   $missingDll=($null -eq $v.ServiceDll)
   $missingMain=($s.Main -and $null -eq $v.ServiceMain)
   Write-Host "[$($s.Name)] Status=$($svc.Status); Signature=$($sig.Status); ServiceDll=$($v.ServiceDll); ServiceMain=$($v.ServiceMain)"
   if($missingDll -or $missingMain){Write-Warning 'Known configuration value missing.'}
   if($Mode -ne 'Repair'){continue}
   if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Microsoft'){throw 'DLL signature check failed; no changes made.'}
   $groupPattern='(?i)\s-k\s+'+[regex]::Escape($s.Group)+'(?:\s|$)'
   if($cfg.ImagePath -notmatch $groupPattern -or $cfg.ImagePath -notmatch '(?i)svchost\.exe'){throw 'Unexpected service host configuration; skipped.'}
   if($cfg.Start -eq 4){throw 'Service disabled; skipped.'}
   if(-not $missingDll -and [Environment]::ExpandEnvironmentVariables($v.ServiceDll) -ine $dll){throw 'Unexpected existing ServiceDll; skipped.'}
   if($s.Main -and -not $missingMain -and $v.ServiceMain -cne $s.Main){throw 'Unexpected existing ServiceMain; skipped.'}
   if($missingDll -or $missingMain){
    $backup=Join-Path $root ($s.Name+'-before.reg')
    & reg.exe export ('HKLM\SYSTEM\CurrentControlSet\Services\'+$s.Name) $backup /y
    if($LASTEXITCODE -ne 0){throw 'Registry backup failed; skipped.'}
    $createdKey=-not (Test-Path $p)
    $undo=@('Windows Registry Editor Version 5.00','')
    $key='HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\'+$s.Name+'\Parameters'
    if($createdKey){$undo+=('[-'+$key+']')}else{$undo+=('['+$key+']');if($missingDll){$undo+='"ServiceDll"=-'};if($missingMain){$undo+='"ServiceMain"=-'}}
    $undo | Set-Content -Encoding Unicode (Join-Path $root ($s.Name+'-undo-added-values.reg'))
    New-Item -Path $p -Force | Out-Null
    if($missingDll){New-ItemProperty -Path $p -Name ServiceDll -PropertyType ExpandString -Value ('%SystemRoot%\System32\'+$s.Dll) | Out-Null}
    if($missingMain){New-ItemProperty -Path $p -Name ServiceMain -PropertyType String -Value $s.Main | Out-Null}
   }
   Start-Service $s.Name
   (Get-Service $s.Name).WaitForStatus('Running',[TimeSpan]::FromSeconds(20))
   Write-Host "[$($s.Name)] Startup verified." -ForegroundColor Green
  } catch { $failed=$true; Write-Warning "$($s.Name): $_" }
 }
 if($Mode -eq 'Integrity'){
  & dism.exe /Online /Cleanup-Image /RestoreHealth
  $de=$LASTEXITCODE; Write-Host "DISM exit: $de"
  & sfc.exe /scannow
  $se=$LASTEXITCODE; Write-Host "SFC exit: $se"
  if($de -ne 0 -or $se -ne 0){$failed=$true}
 }
 Get-Service -Name wuauserv,DoSvc,UsoSvc,BITS,CryptSvc,TrustedInstaller,InstallService,ClipSVC,AppXSvc -ErrorAction SilentlyContinue | Format-Table Name,Status,StartType
 Get-WinEvent -FilterHashtable @{LogName='System';Id=7000,7001,7023;StartTime=(Get-Date).AddDays(-1)} -MaxEvents 20 -ErrorAction SilentlyContinue | Select TimeCreated,Id,Message | Format-List
 Write-Host 'Stopped demand-start services are not necessarily broken. Startup success does not prove update or Store functionality.'
} catch {$failed=$true; Write-Warning $_} finally {Write-Host "Report folder: $root"; Stop-Transcript | Out-Null}
if($failed){exit 1}; exit 0
