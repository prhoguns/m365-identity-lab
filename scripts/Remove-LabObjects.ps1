<#
.SYNOPSIS
Removes what a lab run created: the users listed in the onboarding record and the config's groups.
.DESCRIPTION
Users are deleted, not purged: Entra ID keeps them in Deleted users for 30 days, where they can be
restored. Only objects the lab created are touched: users by the IDs in logs/onboarded.json, groups
only if their description says the lab created them.
.EXAMPLE
./scripts/Remove-LabObjects.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string] $OnboardingRecord = (Join-Path $PSScriptRoot '../logs/onboarded.json'),
    [hashtable] $Config
)

Import-Module (Join-Path $PSScriptRoot '../M365Lab/M365Lab.psd1') -Force
if (-not $Config) { $Config = & (Get-Module M365Lab) { Get-M365LabConfig } }

if (Test-Path $OnboardingRecord) {
    foreach ($u in Get-Content -Raw $OnboardingRecord | ConvertFrom-Json) {
        if ($PSCmdlet.ShouldProcess($u.UserPrincipalName, 'Delete user (restorable for 30 days)')) {
            Remove-MgUser -UserId $u.Id -ErrorAction Continue
            [pscustomobject]@{ Object = $u.UserPrincipalName; Action = 'Deleted user' }
        }
    }
}

$names = @($Config.DepartmentGroups.Values) + $Config.LicenseGroup + $Config.BreakGlassGroup + $Config.DeviceUsersGroup
foreach ($name in $names | Sort-Object -Unique) {
    $escaped = $name.Replace("'", "''")
    foreach ($g in @(Get-MgGroup -Filter "displayName eq '$escaped'" -Property Id, Description)) {
        if ($g.Description -ne 'Created by m365-identity-lab') { continue }  # never a group the lab did not make
        if ($PSCmdlet.ShouldProcess($name, 'Delete group')) {
            Remove-MgGroup -GroupId $g.Id
            [pscustomobject]@{ Object = $name; Action = 'Deleted group' }
        }
    }
}
