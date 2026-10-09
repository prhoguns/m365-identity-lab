function Disable-M365LabUser {
    <#
    .SYNOPSIS
    Offboards a user: blocks sign-in, ends sessions, removes access, and records what was removed.
    .DESCRIPTION
    In order: block sign-in, revoke refresh tokens (signs the user out everywhere), replace the
    password with a random one, remove every group membership (which also drops group-based
    licences), and remove any directly assigned licences. The account itself is kept so mail and
    files can be handed over before deletion. Each run appends a JSON audit record listing the
    groups and licences removed, so access can be restored if the offboarding was a mistake.
    .EXAMPLE
    Disable-M365LabUser -UserPrincipalName jane.doe@contoso.onmicrosoft.com -Reason 'Resigned' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)][string] $UserPrincipalName,
        [Parameter(Mandatory)][string] $Reason,
        [hashtable] $Config = (Get-M365LabConfig)
    )

    process {
        $user = Get-MgUser -UserId $UserPrincipalName -Property Id, UserPrincipalName, AccountEnabled, AssignedLicenses -ErrorAction Stop
        # Dynamic groups compute their own members and drop the user once the account changes.
        $groups = @(Get-MgUserMemberOf -UserId $user.Id -All |
                Where-Object {
                    $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group' -and
                    $_.AdditionalProperties['groupTypes'] -notcontains 'DynamicMembership'
                })
        # Member enumeration, not ForEach-Object: under -WhatIf, ForEach-Object -MemberName is itself skipped.
        $licences = @($user.AssignedLicenses.SkuId | Where-Object { $_ })

        if (-not $PSCmdlet.ShouldProcess($user.UserPrincipalName, "Block sign-in, revoke sessions, remove $($groups.Count) group(s) and $($licences.Count) licence(s)")) {
            return
        }

        Update-MgUser -UserId $user.Id -AccountEnabled:$false -PasswordProfile @{
            Password                      = New-M365LabPassword -Length 32
            ForceChangePasswordNextSignIn = $true
        }
        Revoke-MgUserSignInSession -UserId $user.Id | Out-Null

        $removed = foreach ($g in $groups) {
            Remove-MgGroupMemberDirectoryObjectByRef -GroupId $g.Id -DirectoryObjectId $user.Id
            $g.AdditionalProperties['displayName']
        }
        if ($licences) {
            Set-MgUserLicense -UserId $user.Id -AddLicenses @() -RemoveLicenses $licences | Out-Null
        }

        $record = [ordered]@{
            time              = (Get-Date).ToUniversalTime().ToString('o')
            userPrincipalName = $user.UserPrincipalName
            id                = $user.Id
            reason            = $Reason
            wasEnabled        = [bool]$user.AccountEnabled
            groupsRemoved     = @($removed)
            licencesRemoved   = $licences
            by                = (Get-MgContext).Account
        }
        $log = $Config.AuditLog
        $null = New-Item -ItemType Directory -Force -Path (Split-Path $log -Parent)
        ($record | ConvertTo-Json -Compress) | Add-Content -Path $log
        [pscustomobject]$record
    }
}
