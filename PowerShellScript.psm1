function OnLibraryUpdated()
{
  $__logger.Info("library updated, fetching games from playnite api")

  # get all applicable games
  $AllGames = $PlayniteApi.Database.Games
  $VisibleGames = $AllGames | Where-Object {$_.Hidden -eq 0}
  $Games = $VisibleGames | Select-Object Id, Name, GameId, PluginId, @{Name='Library'; Expr={ $PluginId = $_.PluginId; $PlayniteApi.Addons.Plugins | where { $_.Id -eq $PluginId } }}

  $__logger.Info("${Games.Count} games found")

  # figure out which process is running
  $PlayniteExe = Get-Process -Name "Playnite*" | Select-Object -ExpandProperty Path
  $PlayniteDir = Split-Path -Path $PlayniteExe -Parent
  $DataDir = $CurrentExtensionDataPath

  $__logger.Info("process path is $PlayniteExe")
  $__logger.Info("install path is $PlayniteDir")
  $__logger.Info("extension data path is $CurrentExtensionDataPath")

  # TODO: If launcher not installed, don't generate a manifest?
  [System.Collections.ArrayList]$ManifestsWithStores =  @()
  foreach ($Game in $Games) {
    # for each store, get the correct exe and launch options
    switch -Wildcard ($Game.Library.Name) {
      "Amazon Games" {
        $StartIn = [AmazonGamesLibrary.AmazonGames]::InstallationPath
        $Target = [AmazonGamesLibrary.AmazonGames]::ClientExecPath
        $LaunchOptions = "amazon-games://play/%GameId%"
      }
      "Battle.net" {
        $StartIn = [BattleNetLibrary.BattleNet]::InstallationPath
        $Target = [BattleNetLibrary.BattleNet]::ClientExecPath
        $LaunchOptions = "--exec=""launch %GameId%"""
      }
      "EA app" {
        $StartIn = [OriginLibrary.Origin]::InstallationPath
        $Target = [OriginLibrary.Origin]::ClientExecPath
        $LaunchOptions = "origin2://library/open"
      }
      "Epic" {
        $StartIn = [EpicLibrary.EpicLauncher]::InstallationPath
        $Target = [EpicLibrary.EpicLauncher]::ClientExecPath
        $LaunchOptions = "-com.epicgames.launcher://apps/%GameId%?action=launch"
      }
      "GOG" {
        $StartIn = [GogLibrary.Gog]::InstallationPath
        $Target = [GogLibrary.Gog]::ClientExecPath
        $LaunchOptions = "/launchViaAutostart /gameId=%GameId% /command=runGame"
      }
      "Steam" {
        $StartIn = [SteamLibrary.Steam]::InstallationPath
        $Target = [SteamLibrary.Steam]::ClientExecPath
        $LaunchOptions = "steam://rungameid/%GameId%"
      }
      "Ubisoft Connect" {
        $StartIn = [UplayLibrary.Uplay]::InstallationPath
        $Target = [UplayLibrary.Uplay]::ClientExecPath
        $LaunchOptions = "uplay://launch/%GameId%"
      }
      default {
        $StartIn = $PlayniteDir
        $Target = "$PlayniteDir\Playnite.DesktopApp"
        $LaunchOptions = "--hidesplashscreen --nolibupdate --start %Id%"
      }
    }
    # convert each game to a SRM manifest, but also add a `store` property for grouping
    $ManifestsWithStores.Add(
      [PSCustomObject]@{
        store = if ($Game.Library.Name -ne $null) { $Game.Library.Name } else { "Playnite" }
        title = $Game.Name;
        target = $Target;
        startIn = $StartIn;
        launchOptions = "$LaunchOptions".Replace("%GameId%", $Game.GameId).Replace("%Id%", $Game.Id)
      }
    )
  }

  # group manifests by store and remove store sub-property
  $ManifestGroups = $ManifestsWithStores | Group-Object store
  foreach ($ManifestGroup in $ManifestGroups) {
    foreach ($Manifest in $ManifestGroup.Group) {
      $Manifest.PSObject.Properties.Remove('store')
    }
  }

  # write each manifest
  $__logger.Info("writing manifest files to $DataDir")

  foreach ($ManifestGroup in $ManifestGroups) {
    $StoreDir = Join-Path -Path $DataDir -ChildPath $ManifestGroup.Name
    New-Item -Path $StoreDir -ItemType "directory" -Force
    $__logger.Info("writing manifest for ${ManifestGroup.Name} to $StoreDir/manifest.json")
    $ManifestGroup.Group | ConvertTo-Json -Compress | Out-File -NoNewline -Encoding utf8 -FilePath "$StoreDir/manifest.json"
  }
}
