# playnite-srm-manifest-generator
Playnite script extension for generating Steam Rom Manager `manifest.json` files.

## Building

Run the following in PowerShell, changing the Playnite install directory where appropriate. The following assumes that Playnite is installed in the `<drive>:\Users\<user>\AppData\Local\Playnite` directory.

```psm1
Invoke-Expression "${env:LOCALAPPDATA}\Playnite\Toolbox.exe pack . ./dist"
```
