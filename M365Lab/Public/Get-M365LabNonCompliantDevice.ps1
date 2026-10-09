function Get-M365LabNonCompliantDevice {
    <#
    .SYNOPSIS
    Intune-managed devices that fail compliance or have stopped checking in, oldest first.
    .DESCRIPTION
    A device that has not synced for -StaleSyncDays is listed even if its last report was
    compliant: its state is unknown, and lost devices usually show up this way first.
    .EXAMPLE
    Get-M365LabNonCompliantDevice -StaleSyncDays 14 | Format-Table
    #>
    [CmdletBinding()]
    param(
        [int] $StaleSyncDays = 30,
        [datetime] $Now = (Get-Date).ToUniversalTime()
    )

    $cutoff = $Now.AddDays(-$StaleSyncDays)
    Get-MgDeviceManagementManagedDevice -All `
        -Property Id, DeviceName, OperatingSystem, OsVersion, ComplianceState, LastSyncDateTime, UserPrincipalName, IsEncrypted |
        Where-Object { $_.ComplianceState -ne 'compliant' -or $_.LastSyncDateTime -lt $cutoff } |
        ForEach-Object {
            [pscustomobject]@{
                DeviceName        = $_.DeviceName
                UserPrincipalName = $_.UserPrincipalName
                OperatingSystem   = "$($_.OperatingSystem) $($_.OsVersion)"
                ComplianceState   = $_.ComplianceState
                Encrypted         = [bool]$_.IsEncrypted
                LastSync          = $_.LastSyncDateTime
                Reason            = if ($_.ComplianceState -ne 'compliant') { "Compliance: $($_.ComplianceState)" } else { "No sync for $StaleSyncDays+ days" }
            }
        } |
        Sort-Object LastSync
}
