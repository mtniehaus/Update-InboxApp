<#PSScriptInfo
.VERSION 1.2.1
.GUID 71904827-7092-4941-9a1f-32c207e65075
.AUTHOR Michael Niehaus
.COMPANYNAME
.COPYRIGHT
.TAGS Windows
.LICENSEURI https://github.com/mtniehaus/Update-InboxApp/LICENSE
.PROJECTURI https://github.com/mtniehaus/Update-InboxApp
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
v1.0.0 - Initial version
v1.2.1 - Write a message when app is successfully updated
#>

<#
.SYNOPSIS
This script will tell Windows to update one or more in-box apps, using the available UWP APIs for doing this.
.DESCRIPTION
This script will tell Windows to update one or more in-box apps, using the available UWP APIs for doing this.
.PARAMETER PackageFamilyName
One or more app IDs that should be updated (e.g. "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe")
.EXAMPLE
.\Update-InboxApp.ps1 -PackageFamilyName Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
.EXAMPLE
Get-AppxPackage | .\Update-InboxApp.ps1
.NOTES
See https://oofhours.com for more information.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)] [String[]] $PackageFamilyName
)

Begin {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | ? { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    function Await($WinRtTask, $ResultType) {
        trap {
            $error.RemoveAt(0)
            Continue
        }
        $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
        $netTask = $asTask.Invoke($null, @($WinRtTask))
        $netTask.Wait(-1) | Out-Null
        $netTask.Result
    }    
}

Process {

    [Windows.ApplicationModel.Store.Preview.InstallControl.AppInstallManager,Windows.ApplicationModel.Store.Preview,ContentType=WindowsRuntime] | Out-Null
    $appManager = New-Object -TypeName Windows.ApplicationModel.Store.Preview.InstallControl.AppInstallManager

    foreach ($app in $PackageFamilyName)
    {
        try
        {
            Write-Verbose "Requesting an update for $app..."
            $updateOp = $appManager.UpdateAppByPackageFamilyNameAsync($app)
            $updateResult = Await $updateOp ([Windows.ApplicationModel.Store.Preview.InstallControl.AppInstallItem])
            while ($true)
            {
                if ($null -eq $updateResult)
                {
                    Write-Verbose "No update available for app: $app"
                    break
                }

                if ($null -eq $updateResult.GetCurrentStatus())
                {
                    Write-Debug "Unxpected: Current status is null."
                    break
                }

                if ($updateResult.GetCurrentStatus().PercentComplete -eq 100)
                {
                    Write-Host "App update completed: $app"
                    break
                }
                Start-Sleep -Seconds 3
            }
        }
        catch [System.AggregateException]
        {
            # If the thing is not installed, we can't update it. In this case, we get an
            # ArgumentException with the message "Value does not fall within the expected
            # range." I cannot figure out why *that* is the error in the case of "app is
            # not installed"... perhaps we could be doing something different/better, but
            # I'm happy to just let this slide for now.
            $problem = $_.Exception.InnerException # we'll just take the first one
            if ($problem.GetType() -eq [System.IO.FileNotFoundException]) {
                Write-Verbose "App is not available on the Microsoft Store: $app"
            } else {
                Write-Warning "Error updating app $app (perhaps it is not installed): $problem"
            }
        }
        catch
        {
            Write-Warning "Unexpected error updating app $app : $_"
        }
    }
}
