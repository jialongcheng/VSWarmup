<#
.SYNOPSIS
    Warmup all Visual Studio instances
.PARAMETER MinVSVersion 
    The mininum VS version to run warmup task
.PARAMETER VSParameters
    The VSParameters to run the warmup task
#>

param (
    [Parameter(Mandatory)]
    [string]$MinVSVersion,
    [Parameter(Mandatory)]
    [string]$VSParameters
)

<#
.SYNOPSIS
    Invokes Visual Studio Locator, if it exists, with the provided arguments.
.DESCRIPTION
    Invokes Visual Studio Locator (vswhere.exe) with the provided arguments.
    If this script is run without the locator present, it will fail.
.PARAMETER Arguments
    Arguments to pass onwards to Visual Studio Locator.
.LINK
    https://learn.microsoft.com/en-us/visualstudio/install/tools-for-managing-visual-studio-instances#using-vswhereexe
#>
function Invoke-VsWhere {
    param
    (
        [Parameter(Mandatory)]
        [string]$Arguments
    )

    Assert-VsWherePresent

    return Invoke-Expression -Command "&'$(Get-VsWherePath)' $Arguments"
}

<#
.SYNOPSIS
    Returns the default path of Visual Studio Locator (vswhere.exe).
#>
function Get-VsWherePath {
    return Join-Path -Path "${env:ProgramFiles(x86)}" -ChildPath "Microsoft Visual Studio\Installer\vswhere.exe"
}

<#
.SYNOPSIS
    Throws an exception if Visual Studio Locator (vswhere.exe) is not present in the default location.
#>
function Assert-VsWherePresent {
    if (-not (Test-Path (Get-VsWherePath))) {
        throw "Visual Studio Locator not found."
        exit $exitcode
    }
}

function Get-VSInstances { 
    $fixedVersion = New-Object System.Version($MinVSVersion)
    $vswhereResult = Invoke-VsWhere "-prerelease -all -format json" | ConvertFrom-Json

    $instancesToReturn = @()
    foreach ($instance in $vswhereResult) {
        $instanceVersion = New-Object System.Version($instance.InstallationVersion)

        if ($instanceVersion -ge $fixedVersion) {
            $instancesToReturn += $instance.ProductPath
        }
    }

    return $instancesToReturn
}

# ---- Main Script Start ----

Write-Host "Invoking VSWhere to find latest VS install"

try {
    $instances = Get-VSInstances

    if (0 -eq $instances.Count) {
        Write-Host "No instance found that has the required minimum version"
        exit $exitcode
    }

    foreach ($instance in $instances) {
        Write-Host "Running warmup task for $instance with $VSParameters"

        Invoke-Expression -Command "&'$instance' $VSParameters"

        Wait-Process (Get-Process "devenv").id -Timeout 600

        Write-Host "Finished warmup task for $instance"
    }
}
catch {
    Write-Warning "Warmup task failed with $_"
    exit $exitcode
}

Write-Host "Warmup task Completed."

$exitcode = 0
exit $exitCode

# ---- Main Script End ----