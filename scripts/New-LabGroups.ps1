<#
.SYNOPSIS
Creates the security groups the lab's config refers to, if they do not exist yet.
.EXAMPLE
./scripts/New-LabGroups.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param([hashtable] $Config)

Import-Module (Join-Path $PSScriptRoot '../M365Lab/M365Lab.psd1') -Force
if (-not $Config) { $Config = & (Get-Module M365Lab) { Get-M365LabConfig } }

$names = @($Config.DepartmentGroups.Values) + $Config.LicenseGroup + $Config.BreakGlassGroup + $Config.DeviceUsersGroup
foreach ($name in $names | Sort-Object -Unique) {
    $escaped = $name.Replace("'", "''")
    $existing = Get-MgGroup -Filter "displayName eq '$escaped'" -Property Id
    if ($existing) {
        [pscustomobject]@{ Group = $name; Action = 'Exists'; Id = $existing.Id }
        continue
    }
    if ($PSCmdlet.ShouldProcess($name, 'Create security group')) {
        $nick = ($name.ToLowerInvariant() -replace '[^a-z0-9]', '')
        $g = New-MgGroup -DisplayName $name -MailEnabled:$false -MailNickname $nick -SecurityEnabled `
            -Description 'Created by m365-identity-lab'
        [pscustomobject]@{ Group = $name; Action = 'Created'; Id = $g.Id }
    }
}
