BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../M365Lab/M365Lab.psd1') -Force
    $script:Config = @{
        Domain           = 'contoso.onmicrosoft.com'
        UsageLocation    = 'CA'
        LicenseGroup     = 'LIC-M365-Standard'
        BreakGlassGroup  = 'SEC-BreakGlass-Excluded'
        DepartmentGroups = @{ Finance = 'SEC-Dept-Finance'; IT = 'SEC-Dept-IT' }
        DeviceUsersGroup = 'SEC-Intune-Users'
        StaleAfterDays   = 90
        AuditLog         = Join-Path $TestDrive 'logs/offboarding.jsonl'
    }
}

Describe 'Helpers' {
    It 'generates long random passwords with every character class' {
        InModuleScope M365Lab {
            $seen = 1..50 | ForEach-Object { New-M365LabPassword }
            $seen | ForEach-Object {
                $_.Length | Should -Be 16
                $_ | Should -MatchExactly '[A-Z]'
                $_ | Should -MatchExactly '[a-z]'
                $_ | Should -Match '[0-9]'
                $_ | Should -Match '[^A-Za-z0-9]'
            }
            ($seen | Select-Object -Unique).Count | Should -Be 50
        }
    }

    It 'builds mail nicknames without accents or invalid characters' {
        InModuleScope M365Lab {
            ConvertTo-M365LabMailNickname -FirstName 'Lucas' -LastName 'Côté' | Should -Be 'lucas.cote'
            ConvertTo-M365LabMailNickname -FirstName "Mary-Jo" -LastName "O'Neil" | Should -Be 'mary-jo.oneil'
        }
    }

    It 'refuses an ambiguous group name' {
        Mock -ModuleName M365Lab Get-MgGroup { @([pscustomobject]@{ Id = 'a' }, [pscustomobject]@{ Id = 'b' }) }
        InModuleScope M365Lab { { Get-M365LabGroupId -DisplayName 'Dupes' } | Should -Throw '*exactly one*' }
    }
}

Describe 'New-M365LabUser' {
    BeforeEach {
        Mock -ModuleName M365Lab Get-MgUser { $null }
        Mock -ModuleName M365Lab Get-MgGroup { [pscustomobject]@{ Id = "id-$($Filter.Split("'")[1])" } }
        Mock -ModuleName M365Lab New-MgUser { [pscustomobject]@{ Id = 'new-user-id' } }
        Mock -ModuleName M365Lab New-MgGroupMember { }
    }

    It 'creates the account with a forced password change and adds department and licence groups' {
        $r = New-M365LabUser -FirstName Amara -LastName Okafor -Department Finance -JobTitle Clerk -Config $Config
        $r.UserPrincipalName | Should -Be 'amara.okafor@contoso.onmicrosoft.com'
        $r.TemporaryPassword | Should -BeOfType [securestring]
        Should -Invoke New-MgUser -ModuleName M365Lab -Times 1 -ParameterFilter {
            $AccountEnabled -and $UsageLocation -eq 'CA' -and $PasswordProfile.ForceChangePasswordNextSignIn -eq $true -and
            $PasswordProfile.Password.Length -ge 16 -and $Department -eq 'Finance'
        }
        Should -Invoke New-MgGroupMember -ModuleName M365Lab -Times 1 -ParameterFilter { $GroupId -eq 'id-SEC-Dept-Finance' }
        Should -Invoke New-MgGroupMember -ModuleName M365Lab -Times 1 -ParameterFilter { $GroupId -eq 'id-LIC-M365-Standard' }
    }

    It 'appends a number when the UPN is taken' {
        Mock -ModuleName M365Lab Get-MgUser { if ($Filter -like "*amara.okafor@*") { [pscustomobject]@{ Id = 'existing' } } }
        $r = New-M365LabUser -FirstName Amara -LastName Okafor -Department Finance -Config $Config
        $r.UserPrincipalName | Should -Be 'amara.okafor2@contoso.onmicrosoft.com'
    }

    It 'skips an unmapped department without stopping the batch' {
        $rows = @(
            [pscustomobject]@{ FirstName = 'A'; LastName = 'One'; Department = 'Legal' }
            [pscustomobject]@{ FirstName = 'B'; LastName = 'Two'; Department = 'IT' }
        )
        $r = $rows | New-M365LabUser -Config $Config -ErrorAction SilentlyContinue -ErrorVariable errs
        @($r).Count | Should -Be 1
        $errs[0] | Should -Match 'Legal'
    }

    It 'changes nothing with -WhatIf' {
        New-M365LabUser -FirstName Amara -LastName Okafor -Department Finance -Config $Config -WhatIf
        Should -Invoke New-MgUser -ModuleName M365Lab -Times 0
        Should -Invoke New-MgGroupMember -ModuleName M365Lab -Times 0
    }
}

Describe 'Disable-M365LabUser' {
    BeforeEach {
        Mock -ModuleName M365Lab Get-MgUser {
            [pscustomobject]@{
                Id = 'u1'; UserPrincipalName = 'jane@contoso.onmicrosoft.com'; AccountEnabled = $true
                AssignedLicenses = @([pscustomobject]@{ SkuId = 'sku-direct' })
            }
        }
        Mock -ModuleName M365Lab Get-MgUserMemberOf {
            foreach ($g in @(
                    @{ Id = 'g1'; Name = 'SEC-Dept-Finance'; Types = @() }
                    @{ Id = 'g2'; Name = 'All Staff (dynamic)'; Types = @('DynamicMembership') }
                )) {
                [pscustomobject]@{ Id = $g.Id; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.group'; displayName = $g.Name; groupTypes = $g.Types } }
            }
            [pscustomobject]@{ Id = 'r1'; AdditionalProperties = @{ '@odata.type' = '#microsoft.graph.directoryRole'; displayName = 'Role' } }
        }
        Mock -ModuleName M365Lab Update-MgUser { }
        Mock -ModuleName M365Lab Revoke-MgUserSignInSession { $true }
        Mock -ModuleName M365Lab Remove-MgGroupMemberDirectoryObjectByRef { }
        Mock -ModuleName M365Lab Set-MgUserLicense { }
        Mock -ModuleName M365Lab Get-MgContext { [pscustomobject]@{ Account = 'admin@contoso.onmicrosoft.com' } }
    }

    It 'blocks sign-in, revokes sessions, removes static groups and direct licences, and audits it' {
        $r = Disable-M365LabUser -UserPrincipalName jane@contoso.onmicrosoft.com -Reason 'Resigned' -Config $Config -Confirm:$false
        Should -Invoke Update-MgUser -ModuleName M365Lab -Times 1 -ParameterFilter { $AccountEnabled -eq $false -and $PasswordProfile.Password.Length -eq 32 }
        Should -Invoke Revoke-MgUserSignInSession -ModuleName M365Lab -Times 1
        Should -Invoke Remove-MgGroupMemberDirectoryObjectByRef -ModuleName M365Lab -Times 1 -ParameterFilter { $GroupId -eq 'g1' }
        Should -Invoke Set-MgUserLicense -ModuleName M365Lab -Times 1 -ParameterFilter { $RemoveLicenses -contains 'sku-direct' }
        $r.groupsRemoved | Should -Be @('SEC-Dept-Finance')

        $audit = Get-Content $Config.AuditLog | Select-Object -Last 1 | ConvertFrom-Json
        $audit.reason | Should -Be 'Resigned'
        $audit.licencesRemoved | Should -Be @('sku-direct')
        $audit.by | Should -Be 'admin@contoso.onmicrosoft.com'
    }

    It 'changes nothing with -WhatIf, and the preview counts what would really be removed' {
        # -WhatIf writes to the host, which only a transcript captures.
        $transcript = Join-Path $TestDrive 'whatif.txt'
        Start-Transcript -Path $transcript | Out-Null
        Disable-M365LabUser -UserPrincipalName jane@contoso.onmicrosoft.com -Reason 'Test' -Config $Config -WhatIf
        Stop-Transcript | Out-Null
        Get-Content -Raw $transcript | Should -Match 'remove 1 group\(s\) and 1 licence\(s\)'
        Should -Invoke Update-MgUser -ModuleName M365Lab -Times 0
        Should -Invoke Revoke-MgUserSignInSession -ModuleName M365Lab -Times 0
    }
}

Describe 'Reports' {
    It 'reports stale and never-used accounts but not active ones' {
        $now = [datetime]'2026-10-01T00:00:00Z'
        Mock -ModuleName M365Lab Get-MgUser {
            [pscustomobject]@{ UserPrincipalName = 'active'; CreatedDateTime = $now.AddDays(-400); SignInActivity = [pscustomobject]@{ LastSuccessfulSignInDateTime = $now.AddDays(-3) } }
            [pscustomobject]@{ UserPrincipalName = 'stale'; CreatedDateTime = $now.AddDays(-400); SignInActivity = [pscustomobject]@{ LastSuccessfulSignInDateTime = $now.AddDays(-120) } }
            [pscustomobject]@{ UserPrincipalName = 'never'; CreatedDateTime = $now.AddDays(-200); SignInActivity = $null }
            [pscustomobject]@{ UserPrincipalName = 'new'; CreatedDateTime = $now.AddDays(-10); SignInActivity = $null }
        }
        $r = Get-M365LabStaleUser -Days 90 -Now $now
        $r.UserPrincipalName | Should -Be @('stale', 'never')
        ($r | Where-Object UserPrincipalName -EQ 'never').NeverSignedIn | Should -BeTrue
        ($r | Where-Object UserPrincipalName -EQ 'stale').DaysInactive | Should -Be 120
    }

    It 'lists MFA gaps with administrators first' {
        Mock -ModuleName M365Lab Get-MgReportAuthenticationMethodUserRegistrationDetail {
            [pscustomobject]@{ UserPrincipalName = 'ok'; IsAdmin = $false; IsMfaCapable = $true; MethodsRegistered = @('microsoftAuthenticatorPush') }
            [pscustomobject]@{ UserPrincipalName = 'user-none'; IsAdmin = $false; IsMfaCapable = $false; MethodsRegistered = @() }
            [pscustomobject]@{ UserPrincipalName = 'admin-sms'; IsAdmin = $true; IsMfaCapable = $true; MethodsRegistered = @('mobilePhone') }
        }
        $r = Get-M365LabMfaGap
        $r.UserPrincipalName | Should -Be @('admin-sms', 'user-none')
        $r[0].Issue | Should -Be 'Phone methods only'
    }

    It 'lists noncompliant and silent devices' {
        $now = [datetime]'2026-10-01T00:00:00Z'
        Mock -ModuleName M365Lab Get-MgDeviceManagementManagedDevice {
            [pscustomobject]@{ DeviceName = 'ok'; ComplianceState = 'compliant'; LastSyncDateTime = $now.AddDays(-1) }
            [pscustomobject]@{ DeviceName = 'bad'; ComplianceState = 'noncompliant'; LastSyncDateTime = $now.AddDays(-1) }
            [pscustomobject]@{ DeviceName = 'silent'; ComplianceState = 'compliant'; LastSyncDateTime = $now.AddDays(-45) }
        }
        $r = Get-M365LabNonCompliantDevice -StaleSyncDays 30 -Now $now
        $r.DeviceName | Should -Be @('silent', 'bad')
    }
}

Describe 'Publish-M365LabConditionalAccess' {
    BeforeEach {
        Mock -ModuleName M365Lab Get-MgGroup { [pscustomobject]@{ Id = 'bg-id' } }
        Mock -ModuleName M365Lab Get-MgIdentityConditionalAccessPolicy { [pscustomobject]@{ Id = 'p2'; DisplayName = 'CA02 - Block legacy authentication' } }
        Mock -ModuleName M365Lab New-MgIdentityConditionalAccessPolicy { [pscustomobject]@{ Id = 'new' } }
        Mock -ModuleName M365Lab Update-MgIdentityConditionalAccessPolicy { }
    }

    It 'creates new policies and updates existing ones, report-only, with the break-glass group filled in' {
        $r = Publish-M365LabConditionalAccess -Config $Config -Confirm:$false
        $r.Count | Should -Be 3
        $r.State | Select-Object -Unique | Should -Be 'enabledForReportingButNotEnforced'
        Should -Invoke New-MgIdentityConditionalAccessPolicy -ModuleName M365Lab -Times 2 -ParameterFilter {
            $BodyParameter.conditions.users.excludeGroups -contains 'bg-id' -and $BodyParameter.state -eq 'enabledForReportingButNotEnforced'
        }
        Should -Invoke Update-MgIdentityConditionalAccessPolicy -ModuleName M365Lab -Times 1 -ParameterFilter { $ConditionalAccessPolicyId -eq 'p2' }
    }

    It 'turns policies on only with -Enforce' {
        Publish-M365LabConditionalAccess -Config $Config -Enforce -Confirm:$false | Out-Null
        Should -Invoke New-MgIdentityConditionalAccessPolicy -ModuleName M365Lab -Times 2 -ParameterFilter { $BodyParameter.state -eq 'enabled' }
    }

    It 'refuses a policy that does not exclude the break-glass group' {
        $dir = Join-Path $TestDrive 'ca'
        New-Item -ItemType Directory $dir | Out-Null
        '{"displayName":"Bad","conditions":{"users":{"includeUsers":["All"]}},"grantControls":{"builtInControls":["block"]}}' |
            Set-Content (Join-Path $dir 'bad.json')
        { Publish-M365LabConditionalAccess -Path $dir -Config $Config -Confirm:$false } | Should -Throw '*break-glass*'
        Should -Invoke New-MgIdentityConditionalAccessPolicy -ModuleName M365Lab -Times 0
    }
}

Describe 'Publish-M365LabCompliancePolicy' {
    It 'creates missing policies, keeps existing ones, and assigns both to the device group' {
        Mock -ModuleName M365Lab Get-MgGroup { [pscustomobject]@{ Id = 'devices-id' } }
        Mock -ModuleName M365Lab Get-MgDeviceManagementDeviceCompliancePolicy { [pscustomobject]@{ Id = 'win'; DisplayName = 'Windows - baseline compliance' } }
        Mock -ModuleName M365Lab New-MgDeviceManagementDeviceCompliancePolicy { [pscustomobject]@{ Id = 'ios' } }
        Mock -ModuleName M365Lab Get-MgDeviceManagementDeviceCompliancePolicyAssignment { }
        Mock -ModuleName M365Lab New-MgDeviceManagementDeviceCompliancePolicyAssignment { }
        $r = Publish-M365LabCompliancePolicy -Config $Config
        ($r | Where-Object Id -EQ 'win').Action | Should -Be 'Exists, assigned'
        ($r | Where-Object Id -EQ 'ios').Action | Should -Be 'Created, assigned'
        Should -Invoke New-MgDeviceManagementDeviceCompliancePolicy -ModuleName M365Lab -Times 1
        Should -Invoke New-MgDeviceManagementDeviceCompliancePolicyAssignment -ModuleName M365Lab -Times 2 -ParameterFilter { $BodyParameter.Target.AdditionalProperties['groupId'] -eq 'devices-id' }
    }
}
