#Requires -Version 7.2
# Loads every function in Private/ and Public/; only Public/ functions are exported (see the manifest).
foreach ($folder in 'Private', 'Public') {
    foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot $folder) -Filter '*.ps1') {
        . $file.FullName
    }
}
