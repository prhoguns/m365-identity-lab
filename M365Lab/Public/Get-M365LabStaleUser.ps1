function Get-M365LabStaleUser {
    <#
    .SYNOPSIS
    Enabled accounts with no sign-in for N days, or never used since creation N days ago.
    .DESCRIPTION
    Uses signInActivity, which needs AuditLog.Read.All and an Entra ID P1 licence in the tenant.
    lastSuccessfulSignInDateTime is preferred over lastSignInDateTime, which also counts failures.
    Guests are reported separately via the UserType column because they are reviewed by their sponsor.
    .EXAMPLE
    Get-M365LabStaleUser -Days 90 | Export-Csv stale.csv -NoTypeInformation
    #>
    [CmdletBinding()]
    param(
        [int] $Days = (Get-M365LabConfig).StaleAfterDays,
        [datetime] $Now = (Get-Date).ToUniversalTime()
    )

    $cutoff = $Now.AddDays(-$Days)
    $users = Get-MgUser -All -Filter 'accountEnabled eq true' `
        -Property Id, UserPrincipalName, DisplayName, UserType, CreatedDateTime, SignInActivity

    foreach ($u in $users) {
        $last = $u.SignInActivity.LastSuccessfulSignInDateTime
        if (-not $last) { $last = $u.SignInActivity.LastSignInDateTime }
        $stale = if ($last) { $last -lt $cutoff } else { $u.CreatedDateTime -lt $cutoff }
        if (-not $stale) { continue }
        [pscustomobject]@{
            UserPrincipalName = $u.UserPrincipalName
            DisplayName       = $u.DisplayName
            UserType          = $u.UserType
            LastSignIn        = $last
            Created           = $u.CreatedDateTime
            DaysInactive      = [int]($Now - $(if ($last) { $last } else { $u.CreatedDateTime })).TotalDays
            NeverSignedIn     = -not $last
        }
    }
}
