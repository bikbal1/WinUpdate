# Install driver updates
# Skips drivers that are already installed.

$MaxDriverAttempts = 3

Write-Host ""
Write-Host "Checking installed drivers..." -ForegroundColor Yellow

$InstalledDrivers = Get-CimInstance Win32_PnPSignedDriver |
    Select-Object DeviceName, DriverVersion, Manufacturer

Write-Host ""
Write-Host "Checking for driver updates..." -ForegroundColor Yellow

try {

    $DriverUpdates = Get-WindowsUpdate -UpdateType Driver -MicrosoftUpdate

    if (-not $DriverUpdates) {

        Write-Host "No driver updates found." -ForegroundColor Green

    }
    else {

        Write-Host "$($DriverUpdates.Count) driver update(s) found."

        $CurrentDriver = 0

        foreach ($Driver in $DriverUpdates) {

            $CurrentDriver++

            $DriverStartTime = Get-Date
            $Installed = $false

            Write-Host ""
            Write-Host "============================================"
            Write-Host "Driver $CurrentDriver of $($DriverUpdates.Count)" -ForegroundColor Yellow
            Write-Host $Driver.Title -ForegroundColor Cyan
            Write-Host "============================================"


            # Check if driver already exists
            $ExistingDriver = $InstalledDrivers | Where-Object {

                $_.DeviceName -like "*$($Driver.Title)*"

            }


            if ($ExistingDriver) {

                Write-Host "Driver already installed. Skipping." -ForegroundColor DarkYellow
                Write-Host "Installed version: $($ExistingDriver.DriverVersion)" -ForegroundColor Cyan

                continue

            }


            for ($Attempt = 1; $Attempt -le $MaxDriverAttempts; $Attempt++) {

                Write-Host "Attempt $Attempt of $MaxDriverAttempts"


                try {

                    Install-WindowsUpdate `
                        -UpdateID $Driver.UpdateID `
                        -AcceptAll `
                        -Confirm:$false `
                        -IgnoreReboot `
                        -Verbose `
                        -ErrorAction Stop


                    $DriverElapsedTime = (Get-Date) - $DriverStartTime


                    Write-Host "Successfully installed driver." -ForegroundColor Green
                    Write-Host "Driver time: $($DriverElapsedTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan


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

                $DriverElapsedTime = (Get-Date) - $DriverStartTime

                Write-Host ""
                Write-Host "Skipping driver after failed attempts:" -ForegroundColor Red
                Write-Host $Driver.Title
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
