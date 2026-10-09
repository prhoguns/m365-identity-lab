# Tenant-specific settings. Copy to lab.local.psd1 (git-ignored) and edit for a real tenant.
@{
    # Verified domain new accounts are created in.
    Domain             = 'contoso.onmicrosoft.com'
    UsageLocation      = 'CA'

    # Group-based licensing: members of this group get the Microsoft 365 licence, so onboarding never
    # assigns a SKU directly and offboarding only has to remove group memberships.
    LicenseGroup       = 'LIC-M365-Standard'

    # Emergency-access accounts. Every Conditional Access policy must exclude this group, or a bad
    # policy can lock every administrator out of the tenant.
    BreakGlassGroup    = 'SEC-BreakGlass-Excluded'

    # Department in the HR feed -> security group for access to that department's resources.
    DepartmentGroups   = @{
        Finance    = 'SEC-Dept-Finance'
        Operations = 'SEC-Dept-Operations'
        Sales      = 'SEC-Dept-Sales'
        IT         = 'SEC-Dept-IT'
    }

    # Who gets the Intune compliance policies.
    DeviceUsersGroup   = 'SEC-Intune-Users'

    # Days without a sign-in before an enabled account is reported as stale.
    StaleAfterDays     = 90

    # Where offboarding writes its audit trail (one JSON object per line).
    AuditLog           = 'logs/offboarding.jsonl'
}
