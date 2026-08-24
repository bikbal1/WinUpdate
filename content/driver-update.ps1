# Description:
# Installs PSWindowsUpdate, installs available driver updates,
# skips selected updates/drivers, skips failed drivers without retrying,
# and manually restarts the computer when everything is finished.

# ============================================================
# SETTINGS
# ============================================================

# How many attempts we want to try and install the module.
$MaxAttempts = 5

# Windows Update KBs to ALWAYS skip.
$SkipKBs = @(
    "KB5044285"
    "KB5121003"
)

# Driver UpdateIDs to ALWAYS skip.
$SkipDriverUpdateIDs = @(
    # Example:
    # "12345678-ABCD-1234-ABCD-123456789ABC"
)

# Driver title patterns to ALWAYS skip.
$SkipDriverTitlePatterns = @(
    # Example:
    # "*Intel - Extension*"
)

# Track total script runtime.
$ScriptStartTime = Get-Date

# Disable confirmation prompts.
$ConfirmPreference = 'None'

# Keep title visible in PowerShell window.
$host.UI.RawUI.WindowTitle = "Made by Technician Berad from Revivn - Driver Update Tool"

# ============================================================
# BANNER
# ============================================================

Clear-Host

$BannerLine = "======================================================="
$BannerText = "Made by Technician Berad from Revivn to make it easier!"

$ConsoleWidth = $Host.UI.RawUI.WindowSize.Width

$LinePadding = [Math]::Max(0, [Math]::Floor(($ConsoleWidth - $BannerLine.Length) / 2))
$TextPadding = [Math]::Max(0, [Math]::Floor(($ConsoleWidth - $BannerText.Length) / 2))

Write-Host (" " * $LinePadding + $BannerLine) -ForegroundColor Cyan
Write-Host (" " * $TextPadding + $BannerText) -ForegroundColor Red
Write-Host (" " * $LinePadding + $BannerLine) -ForegroundColor Cyan
Write-Host ""

# ============================================================
# INSTALL / IMPORT PSWINDOWSUPDATE
# ============================================================

for ($i = 1; $i -le $MaxAttempts; $i++) {

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {

        Write-Host "Preparing PSWindowsUpdate Module - Attempt $i of $MaxAttempts"

        try {

            Write-Host "Getting Package Provider..."
            Install-PackageProvider `
                -Name NuGet `
                -Force `
                -Confirm:$false `
                -ErrorAction Stop | Out-Null

            Write-Host "Setting Repository..."
            Set-PSRepository `
                -Name PSGallery `
                -InstallationPolicy Trusted

            Write-Host "Installing PSWindowsUpdate Module..."
            Install-Module `
                -Name PSWindowsUpdate `
                -Force `
                -Confirm:$false `
                -ErrorAction Stop

            Start-Sleep -Seconds 2

            Write-Host "Importing module..."
            Import-Module `
                PSWindowsUpdate `
                -Force `
                -ErrorAction Stop

            Write-Host ""
            Write-Host "PSWindowsUpdate module installed successfully." -ForegroundColor Green

            break

        }
        catch {

            Write-Host ""
            Write-Host "PSWindowsUpdate module installation failed." -ForegroundColor Yellow
            Write-Host $_.Exception.Message -ForegroundColor Yellow

            if ($i -lt $MaxAttempts) {

                Write-Host "Retrying module installation..." -ForegroundColor Cyan
                Start-Sleep -Seconds 5

            }
            else {

                Write-Host ""
                Write-Host "Unable to install PSWindowsUpdate after $MaxAttempts attempts." -ForegroundColor Red
                Write-Host "Driver update process cannot continue." -ForegroundColor Red

                exit 1
            }
        }
    }
    else {

        Write-Host "PSWindowsUpdate already installed." -ForegroundColor Green

        try {

            Import-Module `
                PSWindowsUpdate `
                -Force `
                -ErrorAction Stop

        }
        catch {

            Write-Host ""
            Write-Host "Unable to import PSWindowsUpdate." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            exit 1
        }

        break
    }
}

# ============================================================
# PREPARE WINDOWS UPDATE
# ============================================================

Write-Host ""
Write-Host "Preparing Windows Update components..." -ForegroundColor Cyan

Restart-Service bits -Force -ErrorAction SilentlyContinue
Restart-Service wuauserv -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Checking for driver updates..." -ForegroundColor Yellow

# ============================================================
# FIND DRIVER UPDATES
# ============================================================

try {

    $DriverUpdates = Get-WindowsUpdate `
        -UpdateType Driver `
        -MicrosoftUpdate `
        -ErrorAction Stop

    if (-not $DriverUpdates) {

        Write-Host ""
        Write-Host "No driver updates found." -ForegroundColor Green

    }
    else {

        # ========================================================
        # FILTER OUT SKIPPED KBs
        # ========================================================

        $OriginalDriverCount = $DriverUpdates.Count

        $DriverUpdates = @(
            $DriverUpdates | Where-Object {

                $SkipUpdate = $false

                foreach ($KB in $SkipKBs) {

                    if ($_.KB -contains $KB) {
                        $SkipUpdate = $true
                    }

                    if ($_.Title -like "*$KB*") {
                        $SkipUpdate = $true
                    }
                }

                if ($SkipUpdate) {

                    Write-Host ""
                    Write-Host "Skipping excluded update:" -ForegroundColor DarkYellow
                    Write-Host $_.Title -ForegroundColor Yellow

                    $false
                }
                else {

                    $true
                }
            }
        )

        Write-Host ""
        Write-Host "$($DriverUpdates.Count) driver update(s) found after exclusions." -ForegroundColor Cyan

        if ($OriginalDriverCount -ne $DriverUpdates.Count) {

            $ExcludedCount = $OriginalDriverCount - $DriverUpdates.Count

            Write-Host "$ExcludedCount update(s) excluded." -ForegroundColor DarkYellow
        }

        if ($DriverUpdates.Count -eq 0) {

            Write-Host ""
            Write-Host "No driver updates remain after exclusions." -ForegroundColor Green

        }
        else {

            # Track results
            $SuccessfulDrivers = @()
            $SkippedDrivers = @()

            $CurrentDriver = 0

            # ====================================================
            # INSTALL EACH DRIVER ONCE
            # ====================================================

            foreach ($Driver in $DriverUpdates) {

                $CurrentDriver++

                # -----------------------------------------------
                # Check manually excluded driver
                # -----------------------------------------------

                $SkipThisDriver = $false

                if ($SkipDriverUpdateIDs -contains $Driver.UpdateID) {

                    $SkipThisDriver = $true
                }

                foreach ($Pattern in $SkipDriverTitlePatterns) {

                    if ($Driver.Title -like $Pattern) {

                        $SkipThisDriver = $true
                        break
                    }
                }

                if ($SkipThisDriver) {

                    Write-Host ""
                    Write-Host "============================================" -ForegroundColor DarkYellow
                    Write-Host "Driver $CurrentDriver of $($DriverUpdates.Count)" -ForegroundColor Yellow
                    Write-Host "SKIPPING DRIVER" -ForegroundColor DarkYellow
                    Write-Host "============================================" -ForegroundColor DarkYellow

                    Write-Host "Driver: $($Driver.Title)" -ForegroundColor Yellow
                    Write-Host "Update ID: $($Driver.UpdateID)" -ForegroundColor DarkYellow
                    Write-Host "This driver has been manually excluded." -ForegroundColor Cyan

                    $SkippedDrivers += $Driver

                    continue
                }

                # -----------------------------------------------
                # Install driver
                # -----------------------------------------------

                $DriverStartTime = Get-Date

                Write-Host ""
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host "Driver $CurrentDriver of $($DriverUpdates.Count)" -ForegroundColor Yellow
                Write-Host "Installing driver update..." -ForegroundColor Cyan
                Write-Host "============================================" -ForegroundColor Cyan

                Write-Host "Title: $($Driver.Title)" -ForegroundColor White
                Write-Host "Update ID: $($Driver.UpdateID)" -ForegroundColor DarkGray

                try {

                    $DriverInstallStartTime = Get-Date

                    Install-WindowsUpdate `
                        -UpdateID $Driver.UpdateID `
                        -AcceptAll `
                        -Confirm:$false `
                        -IgnoreReboot `
                        -Verbose `
                        -ErrorAction Stop

                    $DriverElapsedTime = (Get-Date) - $DriverInstallStartTime

                    Write-Host ""
                    Write-Host "Successfully installed driver." -ForegroundColor Green
                    Write-Host "Driver time: $($DriverElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

                    $SuccessfulDrivers += $Driver
                }
                catch {

                    $DriverElapsedTime = (Get-Date) - $DriverStartTime

                    Write-Host ""
                    Write-Host "Driver installation failed - SKIPPING DRIVER." -ForegroundColor Yellow
                    Write-Host "Continuing with the next driver." -ForegroundColor Cyan
                    Write-Host "Driver: $($Driver.Title)" -ForegroundColor Yellow
                    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor DarkYellow
                    Write-Host "Driver time: $($DriverElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

                    $SkippedDrivers += $Driver

                    # NO RETRY.
                    continue
                }
            }

            # ====================================================
            # INSTALLATION SUMMARY
            # ====================================================

            Write-Host ""
            Write-Host "=======================================================" -ForegroundColor Cyan
            Write-Host "Driver Installation Summary" -ForegroundColor Cyan
            Write-Host "=======================================================" -ForegroundColor Cyan

            Write-Host ""
            Write-Host "Successfully installed: $($SuccessfulDrivers.Count)" -ForegroundColor Green
            Write-Host "Skipped/failed:          $($SkippedDrivers.Count)" -ForegroundColor Yellow
            Write-Host "Total processed:         $($DriverUpdates.Count)" -ForegroundColor Cyan

            if ($SuccessfulDrivers.Count -gt 0) {

                Write-Host ""
                Write-Host "Successfully installed drivers:" -ForegroundColor Green

                foreach ($Driver in $SuccessfulDrivers) {

                    Write-Host "  + $($Driver.Title)" -ForegroundColor Green
                }
            }

            if ($SkippedDrivers.Count -gt 0) {

                Write-Host ""
                Write-Host "Skipped/failed drivers:" -ForegroundColor Yellow

                foreach ($Driver in $SkippedDrivers) {

                    Write-Host "  - $($Driver.Title)" -ForegroundColor Yellow
                }
            }
        }
    }
}
catch {

    Write-Host ""
    Write-Host "Driver update scan failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

# ============================================================
# FINAL RUNTIME
# ============================================================

$TotalElapsedTime = (Get-Date) - $ScriptStartTime

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Driver update process completed." -ForegroundColor Green
Write-Host "Total elapsed time: $($TotalElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# ============================================================
# MANUAL REBOOT
# ============================================================

Write-Host ""
Write-Host "Updates are complete." -ForegroundColor Green
Write-Host "Restarting computer in 5 seconds..." -ForegroundColor Yellow

Start-Sleep -Seconds 5

# Do the reboot ourselves.
# Windows Update is told to ignore reboot requirements,
# so the script controls when the computer restarts.

shutdown.exe /r /t 0 /f
