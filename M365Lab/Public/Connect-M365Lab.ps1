function Connect-M365Lab {
    <#
    .SYNOPSIS
    Signs in to Microsoft Graph with only the permissions the lab uses.
    .DESCRIPTION
    Delegated sign-in: the administrator signs in themselves (browser or device code) and consents
    to these scopes. Nothing is stored by the lab. Use -ReadOnly for the reports alone.
    .EXAMPLE
    Connect-M365Lab -UseDeviceCode
    #>
    [CmdletBinding()]
    param(
        [string] $TenantId,
        [switch] $UseDeviceCode,
        [switch] $ReadOnly
    )

    $scopes = if ($ReadOnly) {
        'User.Read.All', 'Group.Read.All', 'AuditLog.Read.All', 'UserAuthenticationMethod.Read.All',
        'Policy.Read.All', 'DeviceManagementManagedDevices.Read.All', 'DeviceManagementConfiguration.Read.All'
    }
    else {
        'User.ReadWrite.All', 'Group.ReadWrite.All', 'Directory.Read.All', 'AuditLog.Read.All',
        'UserAuthenticationMethod.Read.All', 'Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess',
        'DeviceManagementManagedDevices.Read.All', 'DeviceManagementConfiguration.ReadWrite.All'
    }
    $params = @{ Scopes = $scopes; NoWelcome = $true }
    if ($TenantId) { $params.TenantId = $TenantId }
    if ($UseDeviceCode) { $params.UseDeviceCode = $true }
    Connect-MgGraph @params
    $ctx = Get-MgContext
    Write-Verbose "Connected to tenant $($ctx.TenantId) as $($ctx.Account)"
    $ctx
}
