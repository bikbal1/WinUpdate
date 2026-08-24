# ============================================================
# WINDOWS UPDATE DRIVER TOOL
# ============================================================
#
# Installs PSWindowsUpdate, installs available driver updates,
# skips selected KBs/drivers, skips failed drivers without retrying,
# and manually restarts the computer when everything is finished.
#
# ============================================================


# ============================================================
# SETTINGS
# ============================================================

# How many attempts we want to try and install the module.
$MaxAttempts = 5


# Windows Update KBs to ALWAYS skip.
#
# Add KB numbers here.
#
$SkipKBs = @(
    "KB5044285"
    "KB5121003"
)


# Driver UpdateIDs to ALWAYS skip.
#
# Example:
# "12345678-ABCD-1234-ABCD-123456789ABC"
#
$SkipDriverUpdateIDs = @(
)


# Driver title patterns to ALWAYS skip.
#
# Example:
# "*Intel - Extension*"
# "*NVIDIA*"
#
$SkipDriverTitlePatterns = @(
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

$LinePadding = [Math]::Max(
    0,
    [Math]::Floor(($ConsoleWidth - $BannerLine.Length) / 2)
)

$TextPadding = [Math]::Max(
    0,
    [Math]::Floor(($ConsoleWidth - $BannerText.Length) / 2)
)

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
                -ErrorAction Stop |
                Out-Null


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

    $DriverUpdates = @(
        Get-WindowsUpdate `
            -UpdateType Driver `
            -MicrosoftUpdate `
            -ErrorAction Stop
    )


    if (-not $DriverUpdates -or $DriverUpdates.Count -eq 0) {

        Write-Host ""
        Write-Host "No driver updates found." -ForegroundColor Green

    }
    else {

        # ========================================================
        # SHOW DISCOVERED UPDATES
        # ========================================================

        Write-Host ""
        Write-Host "Updates returned by Windows Update:" -ForegroundColor Cyan
        Write-Host ""

        foreach ($Update in $DriverUpdates) {

            Write-Host "Title: $($Update.Title)" -ForegroundColor White

            Write-Host "KB: $($Update.KB)" -ForegroundColor Yellow

            Write-Host "KBArticleIDs: $($Update.KBArticleIDs)" -ForegroundColor Yellow

            Write-Host "Update ID: $($Update.UpdateID)" -ForegroundColor DarkGray

            Write-Host "---------------------------------------------" -ForegroundColor DarkGray
        }


        # ========================================================
        # FILTER OUT EXCLUDED UPDATES
        # ========================================================

        $OriginalDriverCount = $DriverUpdates.Count


        $DriverUpdates = @(
            $DriverUpdates | Where-Object {

                $Update = $_

                $SkipUpdate = $false

                $MatchedKB = $null


                # ------------------------------------------------
                # CHECK EXCLUDED KBs
                # ------------------------------------------------

                foreach ($KB in $SkipKBs) {

                    # Check .KB property.
                    if (
                        $null -ne $Update.KB -and
                        (@($Update.KB) -contains $KB)
                    ) {

                        $SkipUpdate = $true
                        $MatchedKB = $KB

                        break
                    }


                    # Check .KBArticleIDs property.
                    if (
                        $null -ne $Update.KBArticleIDs -and
                        (@($Update.KBArticleIDs) -contains $KB)
                    ) {

                        $SkipUpdate = $true
                        $MatchedKB = $KB

                        break
                    }


                    # Check the title.
                    if (
                        -not [string]::IsNullOrWhiteSpace($Update.Title) -and
                        $Update.Title -match [regex]::Escape($KB)
                    ) {

                        $SkipUpdate = $true
                        $MatchedKB = $KB

                        break
                    }
                }


                # ------------------------------------------------
                # CHECK EXCLUDED DRIVER UPDATE IDs
                # ------------------------------------------------

                if (
                    -not $SkipUpdate -and
                    $SkipDriverUpdateIDs.Count -gt 0
                ) {

                    if (
                        $SkipDriverUpdateIDs -contains [string]$Update.UpdateID
                    ) {

                        $SkipUpdate = $true
                    }
                }


                # ------------------------------------------------
                # CHECK EXCLUDED DRIVER TITLE PATTERNS
                # ------------------------------------------------

                if (
                    -not $SkipUpdate -and
                    $SkipDriverTitlePatterns.Count -gt 0
                ) {

                    foreach ($Pattern in $SkipDriverTitlePatterns) {

                        if ($Update.Title -like $Pattern) {

                            $SkipUpdate = $true

                            break
                        }
                    }
                }


                # ------------------------------------------------
                # EXCLUDE UPDATE
                # ------------------------------------------------

                if ($SkipUpdate) {

                    Write-Host ""
                    Write-Host "============================================" -ForegroundColor DarkYellow
                    Write-Host "EXCLUDED UPDATE" -ForegroundColor DarkYellow
                    Write-Host "============================================" -ForegroundColor DarkYellow

                    if ($MatchedKB) {

                        Write-Host "Matched KB: $MatchedKB" -ForegroundColor Red
                    }

                    Write-Host "Title: $($Update.Title)" -ForegroundColor Yellow
                    Write-Host "Update ID: $($Update.UpdateID)" -ForegroundColor DarkYellow

                    Write-Host "This update will NOT be installed." -ForegroundColor Cyan

                    $false
                }
                else {

                    $true
                }
            }
        )


        # ========================================================
        # EXCLUSION SUMMARY
        # ========================================================

        Write-Host ""

        Write-Host "$($DriverUpdates.Count) driver update(s) found after exclusions." -ForegroundColor Cyan


        if ($OriginalDriverCount -ne $DriverUpdates.Count) {

            $ExcludedCount = $OriginalDriverCount - $DriverUpdates.Count

            Write-Host "$ExcludedCount update(s) excluded." -ForegroundColor DarkYellow
        }


        # ========================================================
        # NO UPDATES REMAIN
        # ========================================================

        if ($DriverUpdates.Count -eq 0) {

            Write-Host ""
            Write-Host "No driver updates remain after exclusions." -ForegroundColor Green
        }
        else {

            # ====================================================
            # TRACK RESULTS
            # ====================================================

            $SuccessfulDrivers = @()

            $SkippedDrivers = @()

            $CurrentDriver = 0


            # ====================================================
            # INSTALL EACH DRIVER ONCE
            # ====================================================

            foreach ($Driver in $DriverUpdates) {

                $CurrentDriver++


                # =================================================
                # SAFETY CHECK
                #
                # Check exclusions AGAIN immediately before
                # installation.
                #
                # This is intentional.
                # =================================================

                $SkipThisDriver = $false

                $MatchedKB = $null


                # -------------------------------------------------
                # CHECK KB EXCLUSIONS AGAIN
                # -------------------------------------------------

                foreach ($KB in $SkipKBs) {

                    # Check .KB
                    if (
                        $null -ne $Driver.KB -and
                        (@($Driver.KB) -contains $KB)
                    ) {

                        $SkipThisDriver = $true
                        $MatchedKB = $KB

                        break
                    }


                    # Check .KBArticleIDs
                    if (
                        $null -ne $Driver.KBArticleIDs -and
                        (@($Driver.KBArticleIDs) -contains $KB)
                    ) {

                        $SkipThisDriver = $true
                        $MatchedKB = $KB

                        break
                    }


                    # Check title
                    if (
                        -not [string]::IsNullOrWhiteSpace($Driver.Title) -and
                        $Driver.Title -match [regex]::Escape($KB)
                    ) {

                        $SkipThisDriver = $true
                        $MatchedKB = $KB

                        break
                    }
                }


                # -------------------------------------------------
                # CHECK DRIVER UPDATE ID
                # -------------------------------------------------

                if (
                    -not $SkipThisDriver -and
                    $SkipDriverUpdateIDs.Count -gt 0
                ) {

                    if (
                        $SkipDriverUpdateIDs -contains [string]$Driver.UpdateID
                    ) {

                        $SkipThisDriver = $true
                    }
                }


                # -------------------------------------------------
                # CHECK DRIVER TITLE PATTERNS
                # -------------------------------------------------

                if (
                    -not $SkipThisDriver -and
                    $SkipDriverTitlePatterns.Count -gt 0
                ) {

                    foreach ($Pattern in $SkipDriverTitlePatterns) {

                        if ($Driver.Title -like $Pattern) {

                            $SkipThisDriver = $true

                            break
                        }
                    }
                }


                # =================================================
                # SKIP EXCLUDED DRIVER
                # =================================================

                if ($SkipThisDriver) {

                    Write-Host ""
                    Write-Host "============================================" -ForegroundColor DarkYellow
                    Write-Host "Driver $CurrentDriver of $($DriverUpdates.Count)" -ForegroundColor Yellow
                    Write-Host "SKIPPING EXCLUDED DRIVER" -ForegroundColor Red
                    Write-Host "============================================" -ForegroundColor DarkYellow

                    if ($MatchedKB) {

                        Write-Host "Excluded KB: $MatchedKB" -ForegroundColor Red
                    }

                    Write-Host "Driver: $($Driver.Title)" -ForegroundColor Yellow

                    Write-Host "Update ID: $($Driver.UpdateID)" -ForegroundColor DarkYellow

                    Write-Host "This driver has been manually excluded." -ForegroundColor Cyan

                    $SkippedDrivers += $Driver

                    continue
                }


                # =================================================
                # INSTALL DRIVER
                # =================================================

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


                    # =================================================
                    # FINAL KB SAFETY CHECK
                    #
                    # Nothing should be installed if the title,
                    # KB property, or KBArticleIDs contain an
                    # excluded KB.
                    # =================================================

                    $FinalExcludedKB = $null


                    foreach ($KB in $SkipKBs) {

                        if (
                            ($null -ne $Driver.KB -and (@($Driver.KB) -contains $KB)) -or
                            ($null -ne $Driver.KBArticleIDs -and (@($Driver.KBArticleIDs) -contains $KB)) -or
                            (-not [string]::IsNullOrWhiteSpace($Driver.Title) -and $Driver.Title -match [regex]::Escape($KB))
                        ) {

                            $FinalExcludedKB = $KB

                            break
                        }
                    }


                    if ($FinalExcludedKB) {

                        Write-Host ""
                        Write-Host "SAFETY CHECK BLOCKED INSTALLATION." -ForegroundColor Red
                        Write-Host "Excluded KB detected: $FinalExcludedKB" -ForegroundColor Red
                        Write-Host "Driver will NOT be installed." -ForegroundColor Yellow

                        $SkippedDrivers += $Driver

                        continue
                    }


                    # =================================================
                    # INSTALL
                    # =================================================

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


            # ====================================================
            # SUCCESSFUL DRIVERS
            # ====================================================

            if ($SuccessfulDrivers.Count -gt 0) {

                Write-Host ""
                Write-Host "Successfully installed drivers:" -ForegroundColor Green


                foreach ($Driver in $SuccessfulDrivers) {

                    Write-Host "  + $($Driver.Title)" -ForegroundColor Green
                }
            }


            # ====================================================
            # SKIPPED / FAILED DRIVERS
            # ====================================================

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


# ============================================================
# REBOOT
# ============================================================
#
# Windows Update is told to ignore reboot requirements,
# so the script controls when the computer restarts.
#

shutdown.exe /r /t 0 /f
