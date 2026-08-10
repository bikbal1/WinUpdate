# Description: Installs PSWindowsUpdate, installs available driver updates,
# skips any driver that fails, and restarts the computer when finished.

# How many attempts we want to try and install the module.
$MaxAttempts = 5

# Track total script runtime.
$ScriptStartTime = Get-Date

# Disable confirmation prompts.
$ConfirmPreference = 'None'

# Keep title visible in PowerShell window.
$host.UI.RawUI.WindowTitle = "Made by Technician Berad from Revivn - Driver Update Tool"

# Original credits: SapphSky!!
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
# Install and import PSWindowsUpdate module
# ============================================================

for ($i = 1; $i -le $MaxAttempts; $i++) {

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {

        Write-Host "Preparing PSWindowsUpdate Module - Attempt $i of $MaxAttempts"

        try {

            Write-Host "Getting Package Provider..."
            Install-PackageProvider -Name NuGet -Force -Confirm:$false -ErrorAction Stop | Out-Null

            Write-Host "Setting Repository..."
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

            Write-Host "Installing PSWindowsUpdate Module..."
            Install-Module -Name PSWindowsUpdate -Force -Confirm:$false -ErrorAction Stop

            Start-Sleep -Seconds 2

            Write-Host "Importing module..."
            Import-Module PSWindowsUpdate -Force -ErrorAction Stop

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

            Import-Module PSWindowsUpdate -Force -ErrorAction Stop

        }
        catch {

            Write-Host "Unable to import PSWindowsUpdate." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            exit 1

        }

        break
    }
}

# ============================================================
# Prepare Windows Update
# ============================================================

Write-Host ""
Write-Host "Preparing Windows Update components..."

Restart-Service bits -Force -ErrorAction SilentlyContinue
Restart-Service wuauserv -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Checking for driver updates..." -ForegroundColor Yellow

try {

    $DriverUpdates = Get-WindowsUpdate -UpdateType Driver -MicrosoftUpdate -ErrorAction Stop

    if (-not $DriverUpdates) {

        Write-Host ""
        Write-Host "No driver updates found." -ForegroundColor Green

    }
    else {

        Write-Host ""
        Write-Host "$($DriverUpdates.Count) driver update(s) found." -ForegroundColor Cyan

        # Track results
        $SuccessfulDrivers = @()
        $SkippedDrivers = @()

        $CurrentDriver = 0

        # ========================================================
        # Install each driver ONCE
        # ========================================================

        foreach ($Driver in $DriverUpdates) {

            $CurrentDriver++

            $DriverStartTime = Get-Date

            Write-Host ""
            Write-Host "============================================" -ForegroundColor Cyan
            Write-Host "Driver $CurrentDriver of $($DriverUpdates.Count)" -ForegroundColor Yellow
            Write-Host "Installing driver update..." -ForegroundColor Cyan
            Write-Host "============================================" -ForegroundColor Cyan

            Write-Host "Title: $($Driver.Title)" -ForegroundColor White

            # ----------------------------------------------------
            # ONE attempt only
            # ----------------------------------------------------

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
                Write-Host "The script will continue with the next driver." -ForegroundColor Cyan
                Write-Host "Driver: $($Driver.Title)" -ForegroundColor Yellow
                Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor DarkYellow
                Write-Host "Driver time: $($DriverElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

                # Add to skipped list.
                $SkippedDrivers += $Driver

                # IMPORTANT:
                # There is intentionally NO retry here.
                # The script immediately continues to the next driver.

                continue
            }
        }

        # ========================================================
        # Installation Summary
        # ========================================================

        Write-Host ""
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "Driver Installation Summary" -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan

        Write-Host ""
        Write-Host "Successfully installed: $($SuccessfulDrivers.Count)" -ForegroundColor Green
        Write-Host "Skipped/failed:          $($SkippedDrivers.Count)" -ForegroundColor Yellow
        Write-Host "Total drivers processed: $($DriverUpdates.Count)" -ForegroundColor Cyan

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
catch {

    # This only handles a failure of the INITIAL DRIVER SCAN.
    # A single driver's installation failure is handled inside
    # the foreach loop above and will NOT reach this block.

    Write-Host ""
    Write-Host "Driver update scan failed." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow

}

# ============================================================
# Calculate total runtime
# ============================================================

$TotalElapsedTime = (Get-Date) - $ScriptStartTime

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "Driver update process completed." -ForegroundColor Green
Write-Host "Total elapsed time: $($TotalElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Restarting computer in 5 seconds..." -ForegroundColor Yellow

Start-Sleep -Seconds 5

# ============================================================
# Force reboot
# ============================================================

shutdown.exe /r /t 0 /f
