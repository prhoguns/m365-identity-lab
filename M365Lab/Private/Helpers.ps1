function Get-M365LabConfig {
    <#
    .SYNOPSIS
    Loads config/lab.local.psd1 when present, otherwise the committed example config/lab.psd1.
    #>
    [CmdletBinding()]
    param([string] $Path)

    if (-not $Path) {
        $root = Split-Path $PSScriptRoot -Parent | Split-Path -Parent
        $local = Join-Path $root 'config/lab.local.psd1'
        $Path = if (Test-Path $local) { $local } else { Join-Path $root 'config/lab.psd1' }
    }
    Import-PowerShellDataFile -Path $Path
}

function New-M365LabPassword {
    <#
    .SYNOPSIS
    A random temporary password from a cryptographic RNG, with every Entra ID complexity class present.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Returns a string; changes no state.')]
    [CmdletBinding()]
    [OutputType([string])]
    param([ValidateRange(14, 64)][int] $Length = 16)

    $sets = @('ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnpqrstuvwxyz', '23456789', '!@#$%*-_=+?')
    $all = -join $sets
    $chars = [System.Collections.Generic.List[char]]::new()
    foreach ($set in $sets) { $chars.Add($set[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($set.Length)]) }
    while ($chars.Count -lt $Length) { $chars.Add($all[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($all.Length)]) }
    # Shuffle so the guaranteed characters are not always first.
    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $j = [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($i + 1)
        $chars[$i], $chars[$j] = $chars[$j], $chars[$i]
    }
    -join $chars
}

function ConvertTo-M365LabMailNickname {
    <#
    .SYNOPSIS
    first.last, lower case, with accents and anything Entra ID rejects removed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $FirstName, [Parameter(Mandatory)][string] $LastName)

    $text = "$FirstName.$LastName".Normalize([Text.NormalizationForm]::FormD)
    $plain = -join ($text.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    ($plain.ToLowerInvariant() -replace "[^a-z0-9.\-_]", '').Trim('.')
}

function Get-M365LabGroupId {
    <#
    .SYNOPSIS
    Resolves a group's object ID from its display name; fails loudly if it is missing or ambiguous.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string] $DisplayName)

    $escaped = $DisplayName.Replace("'", "''")
    $groups = @(Get-MgGroup -Filter "displayName eq '$escaped'" -Property Id, DisplayName)
    if ($groups.Count -ne 1) {
        throw "Expected exactly one group named '$DisplayName', found $($groups.Count)."
    }
    $groups[0].Id
}
