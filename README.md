# Update-InboxApp

This script will use the WinRT API to tell Windows to update one or more in-box apps from the Microsoft Store, instead of
waiting for them to update in the background.  This can be useful to force updates of broken or vulnerable apps (e.g.
Microsoft.DesktopAppInstaller_8wekyb3d8bbwe needs to be updated because Winget is broken.)

You can also use the PowerShell pipeline to update all the installed apps:

Get-AppxPackage | .\Update-InboxApp

The mechanism for doing this was covered in a comment on Github:

https://github.com/microsoft/winget-cli/discussions/1738

Thanks to https://github.com/dmachaj for showing how this can be done in PowerShell.
