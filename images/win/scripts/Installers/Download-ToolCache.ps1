################################################################################
##  File:  Download-ToolCache.ps1
##  Team:  CI-Build
##  Desc:  Download tool cache
################################################################################

Function Install-NpmPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.String]
        $Name,
        [Parameter(Mandatory=$true)]
        [System.String]
        $NpmRegistry
    )

    Write-Host "Installing npm '$Name' package from '$NpmRegistry'"
    npm install $Name --registry=$NpmRegistry
}

Function InstallTool {
    [CmdletBinding()]
    param(
        [System.IO.FileInfo]$ExecutablePath
    )

    Set-Location -Path $ExecutablePath.DirectoryName -PassThru | Write-Host
    if (Test-Path 'tool.zip') {
        Expand-Archive 'tool.zip' -DestinationPath '.'
    }
    cmd.exe /c 'install_to_tools_cache.bat'
}

# ToolCache Blob
$SourceUrl = "https://vstsagenttools.blob.core.windows.net/tools"

# HostedToolCache Path
$Dest = "C:/"

$Path = "hostedtoolcache/windows"
$ToolsDirectory = $Dest + $Path

# Add AzCopy to the Path
$env:Path = "C:\Program Files (x86)\Microsoft SDKs\Azure\AzCopy;" + $env:Path

Write-Host "Started AzCopy from $SourceUrl to $Dest"
AzCopy /Source:$SourceUrl /Dest:$Dest /S /V /Pattern:$Path

# Temporary remove PyPy & Boost
Remove-Item -Path C:\hostedtoolcache\windows\PyPy -Force -Recurse
Remove-Item -Path C:\hostedtoolcache\windows\Boost -Force -Recurse

# Install ToolCache
Push-Location -Path $ToolsDirectory

Get-ChildItem -Recurse -Depth 4 -Filter install_to_tools_cache.bat | ForEach-Object {
    #In order to work correctly Python 3.4 x86 must be installed after x64, this is achieved by current toolcache catalog structure
    InstallTool -ExecutablePath $_
}

Pop-Location

# Define AGENT_TOOLSDIRECTORY environment variable
$env:AGENT_TOOLSDIRECTORY = $ToolsDirectory
setx AGENT_TOOLSDIRECTORY $ToolsDirectory /M

# Install tools form NPM

$ToolVersionsFileContent = Get-Content -Path "$env:TEMPLATE_DIR./toolcache.json" -Raw
$ToolVersions = ConvertFrom-Json -InputObject $ToolVersionsFileContent

$ToolVersions.PSObject.Properties | ForEach-Object {
    $PackageName = $_.Name
    $PackageVersions = $_.Value
    $NpmPackages = $PackageVersions | ForEach-Object { "$PackageName@$_" }
    foreach($NpmPackage in $NpmPackages) {
        Write-Host $NpmPackage
    }
}

#junction point from the previous Python2 directory to the toolcache Python2
$python2Dir = (Get-Item -Path ($ToolsDirectory + '/Python/2.7*/x64')).FullName
cmd.exe /c mklink /d "C:\Python27amd64" "$python2Dir"
