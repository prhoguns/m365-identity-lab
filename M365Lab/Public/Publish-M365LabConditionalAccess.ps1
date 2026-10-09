function Publish-M365LabConditionalAccess {
    <#
    .SYNOPSIS
    Deploys the Conditional Access policies in policies/conditional-access/ from JSON.
    .DESCRIPTION
    Safety rules, enforced before anything is sent to the tenant:
      - Every policy must exclude the break-glass group ({{BreakGlassGroupId}} in the JSON). A policy
        without it is refused: one mistake would otherwise lock every administrator out.
      - Policies are created in report-only mode (enabledForReportingButNotEnforced) unless -Enforce
        is given, so their effect can be read in the sign-in logs before they block anyone.
      - Idempotent by display name: an existing policy is updated in place, not duplicated.
    .EXAMPLE
    Publish-M365LabConditionalAccess -WhatIf
    Publish-M365LabConditionalAccess            # report-only
    Publish-M365LabConditionalAccess -Enforce   # after reviewing the report-only results
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [string] $Path = (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'policies/conditional-access'),
        [switch] $Enforce,
        [hashtable] $Config = (Get-M365LabConfig)
    )

    $breakGlassId = $null
    $existing = $null
    foreach ($file in Get-ChildItem -Path $Path -Filter '*.json' | Sort-Object Name) {
        $text = Get-Content -Raw -Path $file.FullName
        $policy = $text | ConvertFrom-Json -AsHashtable
        if ($policy.conditions.users.excludeGroups -notcontains '{{BreakGlassGroupId}}') {
            throw "$($file.Name): refusing to deploy a policy that does not exclude the break-glass group."
        }
        if (-not $breakGlassId) { $breakGlassId = Get-M365LabGroupId -DisplayName $Config.BreakGlassGroup }
        if ($null -eq $existing) { $existing = @(Get-MgIdentityConditionalAccessPolicy -All) }

        $policy = ($text -replace '\{\{BreakGlassGroupId\}\}', $breakGlassId) | ConvertFrom-Json -AsHashtable
        $policy.state = if ($Enforce) { 'enabled' } else { 'enabledForReportingButNotEnforced' }

        $current = $existing | Where-Object DisplayName -EQ $policy.displayName
        $action = if ($current) { "Update ($($policy.state))" } else { "Create ($($policy.state))" }
        if (-not $PSCmdlet.ShouldProcess($policy.displayName, $action)) { continue }
        if ($current) {
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $current.Id -BodyParameter $policy
            $id = $current.Id
        }
        else {
            $id = (New-MgIdentityConditionalAccessPolicy -BodyParameter $policy).Id
        }
        [pscustomobject]@{ DisplayName = $policy.displayName; State = $policy.state; Action = $action.Split(' ')[0]; Id = $id }
    }
}
