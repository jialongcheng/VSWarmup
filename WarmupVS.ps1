<#
.SYNOPSIS
    Warmup the latest Visual Studio instance
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
function Invoke-VsWhere
{
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
function Get-VsWherePath
{
    return Join-Path -Path "${env:ProgramFiles(x86)}" -ChildPath "Microsoft Visual Studio\Installer\vswhere.exe"
}

<#
.SYNOPSIS
    Throws an exception if Visual Studio Locator (vswhere.exe) is not present in the default location.
#>
function Assert-VsWherePresent
{
    if(-not (Test-Path (Get-VsWherePath)))
    {
        throw "Visual Studio Locator not found."
        exit $exitcode
    }
}

function Get-VSInstance
{ 
    $vswhereResult = Invoke-VsWhere "-prerelease -latest -format json" | ConvertFrom-Json

    $instanceVersion = New-Object System.Version($vswhereResult.InstallationVersion)

    $fixedVersion = New-Object System.Version($MinVSVersion)

    if ($instanceVersion -ge $fixedVersion)
    {
        return $vswhereResult.ProductPath
    }

    return $null
}

# ---- Main Script Start ----

Write-Host "Invoking VSWhere to find latest VS install"

try {
    $instance = Get-VSInstance

    if ($null -eq $instance)
    {
        Write-Host "No instance found that has the required minimum version"
        exit $exitcode
    }

    Write-Host "Running warmup task for $instance with $VSParameters"

    Invoke-Expression -Command "&'$instance' $VSParameters"

    Wait-Process (Get-Process "devenv").id -Timeout 600
}
catch {
    Write-Warning "Warmup task failed with $_"
    exit $exitcode
}

Write-Host "Warmup task Completed."

$exitcode = 0
exit $exitCode

# ---- Main Script End ----