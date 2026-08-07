# Description: Installs PSWindowsUpdate, installs available driver updates,
# and restarts the computer when finished.

# How many attempts we want to try and install the module.
$MaxAttempts = 5

# Install and import PSWindowsUpdate module
for ($i = 1; $i -le $MaxAttempts; $i++) {

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {

        Write-Progress -Activity "Preparing PSWindowsUpdate Module" -Status "Attempt $i of $MaxAttempts"

        # Original credits: SapphSky!!
        Write-Host "Made by Berad to make it easier!"

        Write-Host "Getting Package Provider..."
        Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null

        Write-Host "Setting Repository..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

        Write-Host "Installing PSWindowsUpdate Module..."
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false

        Start-Sleep -Seconds 2

        Write-Host "Importing module..."
        Import-Module PSWindowsUpdate -Force

        Write-Progress -Activity "Preparing PSWindowsUpdate Module" -Completed

        break
    }
    else {
        Import-Module PSWindowsUpdate -Force
        break
    }
}

# Install driver updates
# This is the different part from original repository from SapphSky's, instead of prompting yes or no, it forces to restart.

Write-Host "Resetting Windows Update components..."

Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service bits -Force -ErrorAction SilentlyContinue

Remove-Item -Path "$env:SystemRoot\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue

Start-Service bits
Start-Service wuauserv

Write-Host "Checking for driver updates..."

try {

    Install-WindowsUpdate -AcceptAll -UpdateType Driver -Confirm:$false -Verbose

    Write-Host "Driver update process completed."

}
catch {

    Write-Host "Driver update failed:"
    Write-Host $_.Exception.Message

}

Write-Host "Restarting computer..."

Start-Sleep -Seconds 15

# Force reboot
shutdown.exe /r /t 0 /f
