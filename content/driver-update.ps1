# Description: Installs PSWindowsUpdate, installs available driver updates,
# and restarts the computer when finished.

# How many attempts we want to try and install the module.
$MaxAttempts = 5

# How many attempts we want to try for each driver.
$MaxDriverAttempts = 10

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
Write-Host (" " * $TextPadding + $BannerText) -ForegroundColor Yellow
Write-Host (" " * $LinePadding + $BannerLine) -ForegroundColor Cyan
Write-Host ""

# Install and import PSWindowsUpdate module
for ($i = 1; $i -le $MaxAttempts; $i++) {

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {

        Write-Host "Preparing PSWindowsUpdate Module - Attempt $i of $MaxAttempts"

        Write-Host "Getting Package Provider..."
        Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null

        Write-Host "Setting Repository..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

        Write-Host "Installing PSWindowsUpdate Module..."
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false

        Start-Sleep -Seconds 2

        Write-Host "Importing module..."
        Import-Module PSWindowsUpdate -Force

        break
    }
    else {
        Write-Host "PSWindowsUpdate already installed."
        Import-Module PSWindowsUpdate -Force
        break
    }
}

# Install driver updates
# This is the different part from original repository from SapphSky's, instead of prompting yes or no, it forces to restart.
# Each driver is attempted multiple times. If it fails after all attempts, it skips and continues.

Write-Host ""
Write-Host "Preparing Windows Update components..."

Restart-Service bits -Force -ErrorAction SilentlyContinue
Restart-Service wuauserv -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Checking for driver updates..." -ForegroundColor Yellow

try {

    $DriverUpdates = Get-WindowsUpdate -UpdateType Driver -MicrosoftUpdate

    if (-not $DriverUpdates) {

        Write-Host "No driver updates found."

    }
    else {

        Write-Host "$($DriverUpdates.Count) driver update(s) found."

        $CurrentDriver = 0

        foreach ($Driver in $DriverUpdates) {

            $CurrentDriver++

            # Track individual driver installation time.
            $DriverStartTime = Get-Date

            $Installed = $false

            Write-Host ""
            Write-Host "============================================"
            Write-Host "Driver $CurrentDriver of $($DriverUpdates.Count)" -ForegroundColor Yellow
            Write-Host "Installing driver update..." -ForegroundColor Cyan
            Write-Host "============================================"
            # Check if driver already exists.
            $InstalledDriver = Get-CimInstance Win32_PnPSignedDriver |
            Where-Object {
                $_.DeviceName -like "*$($Driver.Title)*"
            }

            if ($InstalledDriver) {

                Write-Host "Driver already installed. Skipping." -ForegroundColor DarkYellow
                Write-Host "Installed version: $($InstalledDriver.DriverVersion)" -ForegroundColor Cyan

                continue

            }
# Calculate total runtime.
$TotalElapsedTime = (Get-Date) - $ScriptStartTime

Write-Host ""
Write-Host "Driver update process completed." -ForegroundColor Green
Write-Host "Total elapsed time: $($TotalElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host "Restarting computer in 5 seconds..." -ForegroundColor Yellow

Start-Sleep -Seconds 5

# Force reboot
shutdown.exe /r /t 0 /f


            for ($Attempt = 1; $Attempt -le $MaxDriverAttempts; $Attempt++) {

                Write-Host ""
                Write-Host "Retrying current driver - Attempt $Attempt of $MaxDriverAttempts" -ForegroundColor Yellow

                # Track actual driver download/install time.
                $DriverInstallStartTime = Get-Date

                try {

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


                    $Installed = $true
                    break


                }
                catch {

                    $DriverElapsedTime = (Get-Date) - $DriverInstallStartTime

                    Write-Host ""
                    Write-Host "Driver installation failed on attempt $Attempt." -ForegroundColor Yellow
                    Write-Host $_.Exception.Message
                    Write-Host "Attempt time: $($DriverElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan


                    if ($Attempt -lt $MaxDriverAttempts) {

                        Write-Host ""
                        Write-Host "Refreshing Windows Update services before retry..." -ForegroundColor Cyan

                        Restart-Service bits -Force -ErrorAction SilentlyContinue
                        Restart-Service wuauserv -Force -ErrorAction SilentlyContinue

                        Start-Sleep -Seconds 30

                    }

                }
            }


            if (-not $Installed) {

                $DriverElapsedTime = (Get-Date) - $DriverStartTime

                Write-Host ""
                Write-Host "Skipping driver after $MaxDriverAttempts failed attempts:" -ForegroundColor Red
                Write-Host "Driver update skipped."
                Write-Host "Driver time: $($DriverElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan

            }

        }

    }

}
catch {

    Write-Host ""
    Write-Host "Driver update scan failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message

}
