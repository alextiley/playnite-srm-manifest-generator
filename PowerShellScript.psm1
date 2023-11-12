function Write-Manifest {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [PSCustomObject[]]$ManifestsWithStores,
    [Parameter(Mandatory)]
    [string]$OutputDir
  )
  PROCESS {
    $GroupedManifestsWithStores = $ManifestsWithStores | Group-Object store
    foreach ($Group in $GroupedManifestsWithStores) {
      foreach ($Item in $Group.Group) {
        $Item.PSObject.Properties.Remove('store')
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
  # figure out which process is running
  $PlayniteExe = Get-Process -Name "Playnite*" | Select-Object -ExpandProperty Path
  $PlayniteDir = Split-Path -Path $PlayniteExe -Parent

  # get all applicable games
  $AllGames = $PlayniteApi.Database.Games
  $VisibleGames = $AllGames | Where-Object {$_.Hidden -eq 0}
  $GamesWithLibraries = $VisibleGames | Select-Object
    Id,
    Name,
    PluginId,
    @{Name='Library'; Expr={
      $PluginId = $_.PluginId;
      $PlayniteApi.Addons.Plugins | where { $_.Id -eq $PluginId }
    }}

  # convert to SRM manifest format, but also `store` property for grouping later
  $ManifestsWithStores = $GamesWithLibraries | ForEach-Object {
    [PSCustomObject]@{
      store = $_.Library.Name
      title = $_.Name;
      target = "$PlayniteDir\Playnite.DesktopApp";
      startIn = $PlayniteDir;
      launchOptions = "--hidesplashscreen --nolibupdate --start " + $_.Id
    }
  }

  $__logger.Info("Writing manifests to $CurrentExtensionDataPath")

  # write manifest files for each store front
  ,$ManifestsWithStores | Write-Manifest -OutputDir $CurrentExtensionDataPath
}
