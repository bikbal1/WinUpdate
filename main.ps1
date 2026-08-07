# Main script for PowerExpressGUI. This script is responsible for the main GUI and the functions that are called by the GUI.

# Imports
# PresentationFramework and WindowsForms is required for the GUI.
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

$Version = "1.0.4"
$PwrExpDir = "C:"

# Functions
# Cleanup should be ran once the use is finished using the script.
function Cleanup {

  # ResetNetwork resets the network stack.
  # We don't want the next owner to have an existing network connection when they use the computer.
  # The commands run here are referenced from https://www.intel.com/content/www/us/en/support/articles/000058982/wireless/intel-killer-wi-fi-products.html
  function ResetNetwork {
    ipconfig /release
    ipconfig /flushdns
    ipconfig /renew
    netsh int ip reset
    netsh winsock reset
    Write-Host 'Network stack reset.'
  }
}

# WriteComputerInfo writes the Get-ComputerInfo output to a file.
# This is handy to see the computer's information at a glance.
function WriteComputerInfo {
  $FilePath = "$PwrExpDir\computer-info.txt"
  Write-Progress -Activity "Computer Info" -Status "Writing to $FilePath"
  Get-ComputerInfo | Out-File -FilePath $FilePath

  if (Test-Path -Path $FilePath) {
    Write-Host "Computer info created at $FilePath"
  }
  else {
    Write-Host "Error: Computer info failed to generate."
  }
  Write-Progress -Activity "Computer Info" -Completed
}

# WriteBatteryReport saves the battery report to a file.
# We need this for obvious reasons.
function WriteBatteryReport {
  $FilePath = "$PwrExpDir\battery-report.html"
  Write-Progress -Activity "Battery Report" -Status "Writing to $FilePath"
  powercfg /batteryreport /output $FilePath | Out-Null

  if (Test-Path -Path $FilePath) {
    Write-Host "Battery report created at $FilePath"
  }
  else {
    Write-Host "Error: Battery report failed to generate."
  }
  Write-Progress -Activity "Battery Report" -Completed
}

# WriteEnrollmentStatus saves the enrollment status to a file.
# Currently, we are calling this too early in the computer's lifespan.
# The computer hasn't connected with Windows Autopilot or Intune yet to get the latest status.
# TODO: Find a command that calls the Windows Intune API to get the latest status.
function WriteEnrollmentStatus {
  $FilePath = "$PwrExpDir\enrollment-status.txt"

  Write-Progress -Activity "Enrollment Status" -Status "Writing to $FilePath"
  dsregcmd /status | Out-File -FilePath $FilePath
  Start-Sleep -Seconds 1

  if (Test-Path $FilePath) {
    Write-Host "Enrollment status created at $FilePath"
  }
  else {
    Write-Host "Error: Enrollment status failed to generate."
  }
  Write-Progress -Activity "Enrollment Status" -Completed
}

# GetActivationStatus calls the activation status script from the activation server.
# This is useful to see if the computer is activated or not.
function GetActivationStatus {
  Invoke-RestMethod https://get.activated.win | Invoke-Expression
}

# AutoInstallDrivers calls the driver update script from the driver update server.
# This will help reduce install times on the computer. No need to go through Windows Update!
function AutoInstallDrivers {
  Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command "Invoke-RestMethod https://github.com/SapphSky/PowerExpressGUI/raw/main/content/driver-update.ps1 | Invoke-Expression"'
}

# Our GUI is created using XAML.
# This is a simple GUI that has buttons to call the functions above.
# The buttons are placed in a grid layout, and we have tabs to view our generated files.
# You can build one using Microsoft Blend in Visual Studio!
[xml]$XAML = @"
<Window x:Class="MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:local="clr-namespace:WpfApp2"
        Title="PowerExpressGUI"
        Width="800"
        Height="450"
        WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize">
    <Grid>
        <Label Content="PowerExpressGUI"
               HorizontalAlignment="Center"
               Margin="0,0,0,0"
               VerticalAlignment="Top"
               FontSize="28"
               FontWeight="Bold">
            <Label.Foreground>
                <LinearGradientBrush EndPoint="0.5,1"
                                     StartPoint="0.5,0">
                    <GradientStop Color="#FFC4C4FF"/>
                    <GradientStop Color="#FFFFC4C4"
                                  Offset="1"/>
                </LinearGradientBrush>
            </Label.Foreground>
        </Label>
        <Label Content="Version $Version | By Joel Fargas"
               VerticalAlignment="Bottom"
               FontSize="10"
               HorizontalAlignment="Left"/>
        <TabControl BorderBrush="#00ACACAC"
                    Background="Transparent"
                    Margin="10,10,10,30">
            <TabItem Header="Home">
                <Grid>
                  <Button x:Name="InstallDriverUpdateButton" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10, 10, 0, 0" Content="Install Driver Updates" />
                  <Button x:Name="GetActivationStatusButton" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10, 35, 0, 0" Content="Check Activation Status" />
                  <Button x:Name="OpenRetestButton" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10, 60, 0, 0" Content="Open Retest" />
                </Grid>
            </TabItem>
            <TabItem Header="Computer Info">
                <Grid>
                  <WebBrowser x:Name="ComputerInfoViewport"
                              Source="$PwrExpDir\computer-info.txt"/>
                </Grid>
            </TabItem>
            <TabItem Header="Battery Report">
                <Grid>
                  <WebBrowser x:Name="BatteryReportViewport"
                              Source="$PwrExpDir\battery-report.html"/>
                </Grid>
            </TabItem>
            <TabItem Header="Enrollment Report">
                <Grid>
                  <WebBrowser x:Name="EnrollmentStatusViewport"
                              Source="$PwrExpDir\enrollment-status.txt"/>
                </Grid>
            </TabItem>
        </TabControl>
    </Grid>
</Window>
"@ -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window' -replace 'x:Class="\S+"', ''

# Before we can show the GUI, we need to call the functions to generate the files.
WriteComputerInfo
WriteBatteryReport
WriteEnrollmentStatus

# We need to set the variables for the buttons.
# This is so we can call the functions when the buttons are clicked.
$XAMLReader = New-Object System.Xml.XmlNodeReader $XAML
$MainWindow = [Windows.Markup.XamlReader]::Load($XAMLReader)
$XAML.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $MainWindow.FindName($_.Name) }

# We need to add the click events to the buttons.
# This is so we can call the functions when the buttons are clicked.
$InstallDriverUpdateButton.Add_Click({ AutoInstallDrivers })
$GetActivationStatusButton.Add_Click({ GetActivationStatus })
$OpenRetestButton.Add_Click({ Start-Process C:\Windows\System32\cmd.exe -ArgumentList "/C start msedge --no-first-run https://retest.us/laptop-no-keypad" })

# And finally we can show our GUI!
$MainWindow.ShowDialog() | Out-Null
