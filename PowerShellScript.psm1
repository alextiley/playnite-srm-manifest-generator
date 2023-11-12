function OnLibraryUpdated()
{
  $__logger.Info("library updated, fetching games from playnite api")

  # get all applicable games
  $AllGames = $PlayniteApi.Database.Games
  $VisibleGames = $AllGames | Where-Object {$_.Hidden -eq 0}
  $GamesWithLibraries = $VisibleGames | Select-Object Id, Name, GameId, PluginId, @{Name='Library'; Expr={ $PluginId = $_.PluginId; $PlayniteApi.Addons.Plugins | where { $_.Id -eq $PluginId } }}

  $__logger.Info("${GamesWithLibraries.Count} games found")

  # figure out which process is running
  $PlayniteExe = Get-Process -Name "Playnite*" | Select-Object -ExpandProperty Path
  $PlayniteDir = Split-Path -Path $PlayniteExe -Parent
  $DataDir = $CurrentExtensionDataPath

  $__logger.Info("process path is $PlayniteExe")
  $__logger.Info("install path is $PlayniteDir")
  $__logger.Info("extension data path is $CurrentExtensionDataPath")

  # todo figure out the target, startIn and launchOptions for each library and game
  #

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

  # group manifests by store and remove store sub-property
  $ManifestGroups = $ManifestsWithStores | Group-Object store
  foreach ($ManifestGroup in $ManifestGroups) {
    foreach ($Manifest in $ManifestGroup.Group) {
      $Manifest.PSObject.Properties.Remove('store')
    }
  }

  # write each manifest
  foreach ($ManifestGroup in $ManifestGroups)
    $StoreDir = Join-Path -Path $OutputDir -ChildPath $ManifestGroup.Name
    New-Item -Path $StoreDir -ItemType "directory" -Force
    $ManifestGroup.Group | ConvertTo-Json -Compress | Out-File -NoNewline -Encoding utf8 -FilePath "$StoreDir/manifest.json"
  }

  # write manifest files for each store front
  $__logger.Info("writing manifests to $DataDir")
}
