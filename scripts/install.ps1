[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$WoWPath = "D:\Games\Blizzard\World of Warcraft\_classic_beta_"
)
$ErrorActionPreference = "Stop"
$Source = Join-Path (Split-Path $PSScriptRoot -Parent) "SimsForeverExporter"
$Addons = Join-Path $WoWPath "Interface\AddOns"
$Destination = Join-Path $Addons "SimsForeverExporter"
if (-not (Test-Path -LiteralPath $WoWPath -PathType Container)) {
    throw "WoW installation not found: $WoWPath. Pass -WoWPath with your Beta installation."
}
foreach ($File in @("SimsForeverExporter.toc", "Core.lua", "UI.lua")) {
    if (-not (Test-Path -LiteralPath (Join-Path $Source $File) -PathType Leaf)) {
        throw "Addon source is incomplete: $File"
    }
}
# Never recurse into a linked destination or delete existing addon directories.
foreach ($Path in @($WoWPath, (Join-Path $WoWPath "Interface"), $Addons, $Destination)) {
    if (Test-Path -LiteralPath $Path) {
        if ((Get-Item -LiteralPath $Path).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to write through linked directory: $Path"
        }
    }
}
if ($PSCmdlet.ShouldProcess($Destination, "Install SimsForeverExporter files")) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($File in @("SimsForeverExporter.toc", "Core.lua", "UI.lua")) {
        $Target = Join-Path $Destination $File
        if (Test-Path -LiteralPath $Target) {
            if ((Get-Item -LiteralPath $Target).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing to overwrite linked file: $Target"
            }
        }
        Copy-Item -LiteralPath (Join-Path $Source $File) -Destination $Target -Force
    }
    Write-Output "Installed to $Destination. Restart WoW, enable the addon, and run /sfexport outside combat."
}
