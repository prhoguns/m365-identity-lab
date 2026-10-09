function Get-M365LabMfaGap {
    <#
    .SYNOPSIS
    Users who cannot do MFA, administrators first, so a "require MFA" policy can be enforced safely.
    .DESCRIPTION
    Reads the authentication-methods registration report. A user who is not MFA-capable will be
    blocked, or prompted to register on first sign-in, once Conditional Access requires MFA; this
    is the list to clear before switching the policy from report-only to on. Users whose only
    methods are SMS or voice are flagged too, since those are the weakest methods.
    .EXAMPLE
    Get-M365LabMfaGap | Format-Table
    #>
    [CmdletBinding()]
    param()

    $weak = 'mobilePhone', 'alternateMobilePhone', 'officePhone'
    Invoke-M365LabRead -Needs 'Entra ID P1 (authentication methods report)' {
        Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop
    } |
        Where-Object { -not $_.IsMfaCapable -or -not ($_.MethodsRegistered | Where-Object { $_ -notin $weak }) } |
        ForEach-Object {
            [pscustomobject]@{
                UserPrincipalName = $_.UserPrincipalName
                IsAdmin           = [bool]$_.IsAdmin
                MfaCapable        = [bool]$_.IsMfaCapable
                Methods           = ($_.MethodsRegistered -join ', ')
                Issue             = if (-not $_.IsMfaCapable) { 'No MFA method' } else { 'Phone methods only' }
            }
        } |
        Sort-Object @{ Expression = 'IsAdmin'; Descending = $true }, @{ Expression = 'MfaCapable' }, UserPrincipalName
}
