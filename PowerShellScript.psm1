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
  $__logger.Info("library updated, fetching games from playnite api")

  # get all applicable games
  $AllGames = $PlayniteApi.Database.Games
  $VisibleGames = $AllGames | Where-Object {$_.Hidden -eq 0}
  $GamesWithLibraries = $VisibleGames | Select-Object Id, Name, PluginId, @{Name='Library'; Expr={ $PluginId = $_.PluginId; $PlayniteApi.Addons.Plugins | where { $_.Id -eq $PluginId } }}

  $__logger.Info("${GamesWithLibraries.Count} games found")

  # todo get the underlying play action so we can invoke that from steam directly
  #

  # figure out which process is running
  $PlayniteExe = Get-Process -Name "Playnite*" | Select-Object -ExpandProperty Path
  $PlayniteDir = Split-Path -Path $PlayniteExe -Parent
  $DataDir = $CurrentExtensionDataPath

  $__logger.Info("process path is $PlayniteExe")
  $__logger.Info("install path is $PlayniteExe")
  $__logger.Info("extension data path is $CurrentExtensionDataPath")

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

  # write manifest files for each store front
  $__logger.Info("writing manifests to $DataDir")
  ,$ManifestsWithStores | Write-Manifest -OutputDir $DataDir
}
