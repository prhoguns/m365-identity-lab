function Publish-M365LabCompliancePolicy {
    <#
    .SYNOPSIS
    Deploys the Intune device compliance policies in policies/intune/ and assigns them.
    .DESCRIPTION
    Idempotent by display name: an existing policy is left as it is and only its assignment is
    checked, because Intune rejects a PATCH that changes a policy's platform type. Each policy is
    assigned to the device-users group from the config.
    .EXAMPLE
    Publish-M365LabCompliancePolicy -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string] $Path = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'policies/intune'),
        [hashtable] $Config = (Get-M365LabConfig)
    )

    $groupId = $null
    $existing = $null
    foreach ($file in Get-ChildItem -Path $Path -Filter '*.json' | Sort-Object Name) {
        $policy = Get-Content -Raw -Path $file.FullName | ConvertFrom-Json -AsHashtable
        if (-not $policy.scheduledActionsForRule) {
            throw "$($file.Name): Intune requires scheduledActionsForRule with at least a block action."
        }
        if (-not $groupId) { $groupId = Get-M365LabGroupId -DisplayName $Config.DeviceUsersGroup }
        if ($null -eq $existing) { $existing = @(Get-MgDeviceManagementDeviceCompliancePolicy -All) }

        $current = $existing | Where-Object DisplayName -EQ $policy.displayName
        if ($current) {
            $id = $current.Id
            $action = 'Exists'
        }
        else {
            if (-not $PSCmdlet.ShouldProcess($policy.displayName, 'Create compliance policy')) { continue }
            $id = (New-MgDeviceManagementDeviceCompliancePolicy -BodyParameter $policy).Id
            $action = 'Created'
        }

        $assigned = @(Get-MgDeviceManagementDeviceCompliancePolicyAssignment -DeviceCompliancePolicyId $id) |
            Where-Object { $_.Target.AdditionalProperties['groupId'] -eq $groupId }
        if (-not $assigned -and $PSCmdlet.ShouldProcess($policy.displayName, "Assign to $($Config.DeviceUsersGroup)")) {
            New-MgDeviceManagementDeviceCompliancePolicyAssignment -DeviceCompliancePolicyId $id -BodyParameter @{
                target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $groupId }
            } | Out-Null
            $action += ', assigned'
        }
        [pscustomobject]@{ DisplayName = $policy.displayName; Platform = $policy.'@odata.type'; Action = $action; Id = $id }
    }
}
