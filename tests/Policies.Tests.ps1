BeforeDiscovery {
    $root = Join-Path $PSScriptRoot '..'
    $script:CaFiles = Get-ChildItem (Join-Path $root 'policies/conditional-access') -Filter *.json | ForEach-Object { @{ File = $_ } }
    $script:IntuneFiles = Get-ChildItem (Join-Path $root 'policies/intune') -Filter *.json | ForEach-Object { @{ File = $_ } }
    $script:Scripts = Get-ChildItem (Join-Path $root 'M365Lab') -Recurse -Include *.ps1, *.psm1 | ForEach-Object { @{ File = $_ } }
}

Describe 'Conditional Access policy <File.Name>' -ForEach $CaFiles {
    BeforeAll { $p = Get-Content -Raw $File.FullName | ConvertFrom-Json -AsHashtable }

    It 'excludes the break-glass group' { $p.conditions.users.excludeGroups | Should -Contain '{{BreakGlassGroupId}}' }
    It 'starts in report-only mode' { $p.state | Should -Be 'enabledForReportingButNotEnforced' }
    It 'has a grant control' { $p.grantControls.builtInControls | Should -Not -BeNullOrEmpty }
    It 'names a CA number for change tracking' { $p.displayName | Should -Match '^CA\d{2} - ' }
}

Describe 'Intune policy <File.Name>' -ForEach $IntuneFiles {
    BeforeAll { $p = Get-Content -Raw $File.FullName | ConvertFrom-Json -AsHashtable }

    It 'declares its platform type' { $p.'@odata.type' | Should -Match '^#microsoft\.graph\.\w+CompliancePolicy$' }
    It 'has a block action, which Intune requires' {
        $p.scheduledActionsForRule[0].scheduledActionConfigurations.actionType | Should -Contain 'block'
    }
    It 'requires a minimum OS version' { $p.osMinimumVersion | Should -Not -BeNullOrEmpty }
}

Describe 'Script analysis of <File.Name>' -ForEach $Scripts {
    It 'has no PSScriptAnalyzer warnings or errors' {
        $issues = Invoke-ScriptAnalyzer -Path $File.FullName -Severity Warning, Error -Settings (Join-Path $PSScriptRoot '../PSScriptAnalyzerSettings.psd1')
        $issues | ForEach-Object { "$($_.RuleName) line $($_.Line): $($_.Message)" } | Should -BeNullOrEmpty
    }
}
