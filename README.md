# Windows Repair Toolkit – Microsoft Store & Windows Update Fix
> **Compatibility and warning:** The underlying repair procedures have only been tested on Windows 10 22H2 (build 19045). The packaged toolkit itself has not yet been tested on Windows. Other versions are unsupported. Use at your own risk.

Portable, unsigned source release. No installation required. Extract all files first. Right-click Launch.cmd and run as administrator, or run Repair.ps1 from an elevated 64-bit Windows PowerShell 5.1 session:

    .\Repair.ps1 -Mode Check
    .\Repair.ps1 -Mode Repair
    .\Repair.ps1 -Mode Integrity

Check is read-only with respect to system configuration (writes a report). Repair requires typing REPAIR and is restricted to Windows 10 build 19045. Integrity runs DISM RestoreHealth then SFC scannow; may take a long time and require Windows Update access. No automatic reboot, formatting, application installation, security bypass, or service disabling. If execution policy blocks the script, consult your administrator; do not disable organizational protections.

## Why I Built This Toolkit

I originally encountered an issue while trying to install Codex through the Microsoft Store. The installation was stuck indefinitely, and standard troubleshooting methods failed to resolve the problem.

After further investigation, I discovered missing Windows service registry configurations affecting Windows Update, Delivery Optimization, and Update Orchestrator, even though DISM and SFC reported no system integrity issues.

After successfully restoring these services without formatting or reinstalling Windows, I decided to create this toolkit to help others experiencing similar problems.

The goal is to provide a simple, transparent, and reusable solution for diagnosing and repairing these specific Windows issues while avoiding unnecessary system reinstalls and data loss.

## Scope
Based on a real Windows 10 22H2 repair: missing DoSvc and UsoSvc ServiceDll values and missing wuauserv ServiceMain (WUServiceMain). Repair only adds missing values, checks DLL signatures and service host group, backs up each affected service, and attempts service startup. Existing unexpected values are left alone. Other service issues, missing services, ACLs, Windows Update policies and Store failures are reported or outside scope. Check mode works on other Windows versions but its targeted expectations are not a compatibility guarantee. DISM/SFC exit codes are not proof of full system health.

## Logs and rollback
Reports and registry exports are in C:\ProgramData\WindowsRepairToolkit\<timestamp>. Review logs before sharing: they may contain machine details. Each changed service has a before.reg and undo-added-values.reg. The latter removes only the newly added values (or the newly created Parameters key); review it before importing with elevated reg.exe import. Do not apply rollback if subsequent repairs have changed those keys. Export files alone do not remove newly added values. A reboot may be required after rollback; save work first. Create a system backup or restore point before repair.

## Disclaimer
This toolkit is provided as-is, without warranties or guarantees. It modifies Windows service registry settings in repair mode and requires administrator privileges. Back up your important files and create a restore point or system backup before use. Run Check mode first. You are responsible for deciding whether to run the repairs and for any resulting system changes, data loss, or downtime.

## Release status
The individual registry fixes succeeded on the original PC. This packaged script and launcher have not been executed or tested on Windows; validate on a disposable Windows 10 VM before public distribution. No claim of universal compatibility or guaranteed repair. Windows 10 standard support has ended; use a supported OS or applicable extended security updates. No license is assigned; the publisher should choose one before redistribution.
# windows-repair-toolkit
