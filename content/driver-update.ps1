# Description: This script will install the PSWindowsUpdate module and check for driver updates.
# It will run in a separate window and check for updates. If there are no updates, it will exit.
# You can just run this script by itself by running the command:
# irm https://github.com/SapphSky/PowerExpressGUI/raw/main/content/driver-update.ps1 | iex

# How many attempts we want to try and install the module.
$MaxAttempts = 5

for ($i = 1; $i -le $MaxAttempts; $i++) {
    if (-Not (Get-Module -Name PSWindowsUpdate)) {
        Write-Progress -Activity "Preparing PSWindowsUpdate Module" -Status "Attempt $i of $MaxAttempts"
        Write-Host 'Getting Package Provider'
        Get-PackageProvider -Name Nuget -ForceBootstrap | Out-Null

        Write-Host 'Setting Repository'
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

        Write-Host 'Installing PSWindowsUpdate Module...'
        Install-Module -Name PSWindowsUpdate -Force
        Start-Sleep -Seconds 1

        Write-Host 'Importing module...'
        Import-Module -Name PSWindowsUpdate -Force
        Write-Progress -Activity "Preparing PSWindowsUpdate Module" -Completed
    }
    else {
        Write-Host "Checking for updates..."
        Install-WindowsUpdate -AcceptAll -UpdateType Driver
        break
    }
    $i++
}
