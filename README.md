# win.refurb.sh (formerly PowerExpressGUI)

A PowerShell script to help quickly diagnose and set up a Windows computer with driver updates and diagnostics right after installation.

## Features

* Install drivers using the [PSWindowsUpdate](https://www.powershellgallery.com/packages/pswindowsupdate) module.
* Generate and view the Battery Report using the `powercfg /batteryreport` command.

**Be sure to configure the Wi-Fi settings in the XML file so that the script has access to the internet when running after installation.**

## Usage

If in the OOBE (Out-Of-Box Experience), press Shift + F10 to open a Command Prompt.

Run PowerShell as an Administrator: `powershell`

Once connected to the internet, run the following command:

```
irm win.refurb.sh | iex
```

### Autounattend.xml
No .iso modifications required. Just create an `autounattend.xml` with
You can generate one using [this site](https://schneegans.de/windows/unattend-generator/) (schneegans.de) or use this [preset I made](https://schneegans.de/windows/unattend-generator/view/?LanguageMode=Interactive&ProcessorArchitecture=x86&ProcessorArchitecture=amd64&BypassRequirementsCheck=true&BypassNetworkCheck=true&ComputerNameMode=Random&TimeZoneMode=Implicit&PartitionMode=Interactive&WindowsEditionMode=Unattended&WindowsEdition=pro&UserAccountMode=Interactive&PasswordExpirationMode=Unlimited&LockoutMode=Default&WifiMode=Unattended&WifiName=2ARTech&WifiNonBroadcast=true&WifiAuthentication=WPA2PSK&WifiPassword=qwertyui&ExpressSettings=Interactive&SystemScript0=Invoke-RequestMethod+https%3A%2F%2Fgithub.com%2FSapphSky%2FPowerExpressGUI%2Fraw%2Fmain%2Fpreboot.ps1+%7C+Invoke-Expression&SystemScriptType0=Ps1&WdacMode=Skip)

Attach one of the `autounattend.xml` files to the root of your Windows install USB.

If you are using [Ventoy](https://github.com/Ventoy/Ventoy), make sure to assign it in the Auto Install section of the VentoyPlugon for Windows.

Once the installation has finished and rebooted, you will be connected to the Wi-Fi network automatically, and will begin to run the script.
