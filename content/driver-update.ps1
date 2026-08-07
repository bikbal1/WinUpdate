# Description: Installs PSWindowsUpdate, installs available driver updates,
# and restarts the computer when finished.

# How many attempts we want to try and install the module.
$MaxAttempts = 5

# How many attempts we want to try for each driver.
$MaxDriverAttempts = 10

# Original credits: SapphSky!!
Write-Host "=============================================" -ForegroundColor Red
Write-Host "Made by Berad from Revivn to make it easier!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Blue
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
Write-Host "Resetting Windows Update components..."

Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service bits -Force -ErrorAction SilentlyContinue

Remove-Item -Path "$env:SystemRoot\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue

Start-Service bits
Start-Service wuauserv

Write-Host ""
Write-Host "Checking for driver updates..." -ForegroundColor Yellow

try {

    $DriverUpdates = Get-WindowsUpdate -UpdateType Driver -MicrosoftUpdate

    if (-not $DriverUpdates) {

        Write-Host "No driver updates found."

    }
    else {

        Write-Host "$($DriverUpdates.Count) driver update(s) found."

        foreach ($Driver in $DriverUpdates) {

            $Installed = $false

            Write-Host ""
            Write-Host "Installing driver:"
            Write-Host $Driver.Title -ForegroundColor Cyan

            for ($Attempt = 1; $Attempt -le $MaxDriverAttempts; $Attempt++) {

                Write-Host "Attempt $Attempt of $MaxDriverAttempts"

                try {

                    Install-WindowsUpdate `
                        -UpdateID $Driver.UpdateID `
                        -AcceptAll `
                        -Confirm:$false `
                        -Verbose `
                        -ErrorAction Stop

                    Write-Host "Successfully installed driver." -ForegroundColor Green

                    $Installed = $true
                    break

                }
                catch {

                    Write-Host "Driver installation failed on attempt $Attempt." -ForegroundColor Yellow
                    Write-Host $_.Exception.Message

                    Start-Sleep -Seconds 5
                }
            }

            if (-not $Installed) {

                Write-Host "Skipping driver after $MaxDriverAttempts failed attempts:" -ForegroundColor Red
                Write-Host $Driver.Title

            }
        }
    }

}
catch {

    Write-Host ""
    Write-Host "Driver update scan failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message

}

Write-Host ""
Write-Host "Driver update process completed." -ForegroundColor Green
Write-Host "Restarting computer in 15 seconds..." -ForegroundColor Yellow

Start-Sleep -Seconds 15

# Force reboot
shutdown.exe /r /t 0 /f
