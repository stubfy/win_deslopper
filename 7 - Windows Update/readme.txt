7 - WINDOWS UPDATE
Windows Update profile on demand
================================

USAGE
-----
Run `set_windows_update.bat` as administrator.

The script exposes the same three profiles as `run_all.bat`:
  1. Default
  2. Security
  3. Disabled

Use it when you want to quickly switch Windows Update behavior after the main
setup without re-running the full automated phase.


ROLLBACK
--------
Run `1 - Automated\restore\windows_update.bat` as administrator.

That restore script reapplies profile 1 (`Default`), which is the pack's
WinUtil-aligned Windows Update baseline.


NOTES
-----
- If you launch the PowerShell script directly, `-Profil 1|2|3` is supported
- Profile 2 applies the WinUtil recommended profile: no drivers via WU, feature updates deferred 365 days, quality updates deferred 4 days
- Profile 3 disables the WU services and should only be used knowingly
