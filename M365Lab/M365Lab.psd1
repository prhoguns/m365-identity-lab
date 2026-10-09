@{
    RootModule        = 'M365Lab.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '5d0c6f53-6c1e-4b58-9a43-2f0f7c1d8e21'
    Author            = 'Philips Rhoguns'
    Description       = 'Microsoft 365 identity and device administration with Microsoft Graph: onboarding, offboarding, MFA and stale-account reports, Conditional Access and Intune compliance as code.'
    PowerShellVersion = '7.2'
    RequiredModules   = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Users'
        'Microsoft.Graph.Users.Actions'
        'Microsoft.Graph.Groups'
        'Microsoft.Graph.Identity.SignIns'
        'Microsoft.Graph.Reports'
        'Microsoft.Graph.DeviceManagement'
    )
    FunctionsToExport = @(
        'Connect-M365Lab'
        'New-M365LabUser'
        'Disable-M365LabUser'
        'Get-M365LabStaleUser'
        'Get-M365LabMfaGap'
        'Get-M365LabNonCompliantDevice'
        'Publish-M365LabConditionalAccess'
        'Publish-M365LabCompliancePolicy'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
