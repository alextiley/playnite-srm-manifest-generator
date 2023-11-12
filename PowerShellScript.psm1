function Write-Manifest {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [PSCustomObject[]]$Manifests,
    [Parameter(Mandatory)]
    [string]$OutputDir
  )
  PROCESS {
    $GroupedManifests = $Manifests | Group-Object store
    foreach ($Group in $GroupedManifests) {
      foreach ($Manifest in $Group.Group) {
        $Manifest.PSObject.Properties.Remove('store')
      }
      $Store = $Group.Name
      $StoreDir = Join-Path -Path $OutputDir -ChildPath $Store
      New-Item -Path $StoreDir -ItemType "directory" -Force
      $Group.Group | ConvertTo-Json -Compress | Out-File -NoNewline -Encoding utf8 -FilePath "$StoreDir/manifest.json"
    }
  }
}

function OnLibraryUpdated()
{
  $__logger.Info("OnLibraryUpdated")

  try {
    $PlayniteExe = Get-Process -Name "Playnite.DesktopApp" | Select-Object -ExpandProperty Path
  } catch {
    $PlayniteExe = Get-Process -Name "Playnite.FullscreenApp" | Select-Object -ExpandProperty Path
  }
  $PlayniteDir = Split-Path -Path $PlayniteExe -Parent

  $PlayniteApi.Dialogs.ShowMessage("Library updated, $PlayniteExe will now write manifests to $CurrentExtensionDataPath!")

  # get all games that are not hidden
  $Games = $PlayniteApi.Database.Games | Where-Object {$_.Hidden -eq 0} | Select-Object Id, Name, GameId, Hidden, PluginId, @{Name='Library'; Expr={$PluginId = $_.PluginId; $PlayniteApi.Addons.Plugins | where { $_.Id -eq $PluginId }}}, @{Name='Platforms'; Expr={($_.Platforms| Select-Object -ExpandProperty "Name") -Join '|'}}

  # convert to SRM manifest format
  $Manifests = $Games | ForEach-Object {
    [PSCustomObject]@{
      store = $_.Library.Name
      title = $_.Name;
      target = $PlayniteExe;
      startIn = $PlayniteDir;
      launchOptions = "--hidesplashscreen --nolibupdate --start " + $_.Id
    }
  }

  # write manifest files for each store front
  ,$Manifests | Write-Manifest -OutputDir $CurrentExtensionDataPath
}


$s = "c:\programfiles\tv\version8\uninstall.exe"
Split-Path -Path $s -Leaf
Split-Path -Path $s -Parent
Split-Path -Path (Split-Path -Path $s -Parent) -Leaf
