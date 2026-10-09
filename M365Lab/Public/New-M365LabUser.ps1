function New-M365LabUser {
    <#
    .SYNOPSIS
    Onboards new hires: account, temporary password, department access and licence by group.
    .DESCRIPTION
    Takes rows with FirstName, LastName, Department and JobTitle (for example from an HR CSV).
    For each person it creates the account with a random temporary password that must be changed
    at first sign-in, then adds it to the department group and the licence group. A UPN already in
    use gets a number appended (jane.doe2) rather than failing the batch.

    The temporary password is returned as a SecureString, for delivery to the manager by phone or
    in person, never by email to the new account. -WhatIf shows the plan without changing anything.
    .EXAMPLE
    Import-Csv data/new-hires.csv | New-M365LabUser -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)][string] $FirstName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)][string] $LastName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)][string] $Department,
        [Parameter(ValueFromPipelineByPropertyName)][string] $JobTitle,
        [hashtable] $Config = (Get-M365LabConfig)
    )

    begin {
        $groupCache = @{}
        function Resolve-Group([string] $name) {
            if (-not $groupCache.ContainsKey($name)) { $groupCache[$name] = Get-M365LabGroupId -DisplayName $name }
            $groupCache[$name]
        }
    }

    process {
        if (-not $Config.DepartmentGroups.ContainsKey($Department)) {
            Write-Error "No group is mapped for department '$Department' ($FirstName $LastName); add it to DepartmentGroups."
            return
        }
        $nick = ConvertTo-M365LabMailNickname -FirstName $FirstName -LastName $LastName
        $upn = "$nick@$($Config.Domain)"
        $n = 1
        while (Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property Id -ErrorAction SilentlyContinue) {
            $n++
            $upn = "$nick$n@$($Config.Domain)"
        }
        $mailNickname = $upn.Split('@')[0]

        if (-not $PSCmdlet.ShouldProcess($upn, "Create account in $Department and add to $($Config.DepartmentGroups[$Department]), $($Config.LicenseGroup)")) {
            return
        }
        $password = New-M365LabPassword
        $user = New-MgUser -DisplayName "$FirstName $LastName" -GivenName $FirstName -Surname $LastName `
            -UserPrincipalName $upn -MailNickname $mailNickname -AccountEnabled `
            -Department $Department -JobTitle $JobTitle -UsageLocation $Config.UsageLocation `
            -PasswordProfile @{ Password = $password; ForceChangePasswordNextSignIn = $true } -ErrorAction Stop

        foreach ($groupName in $Config.DepartmentGroups[$Department], $Config.LicenseGroup) {
            New-MgGroupMember -GroupId (Resolve-Group $groupName) -DirectoryObjectId $user.Id -ErrorAction Stop
        }

        [pscustomobject]@{
            UserPrincipalName = $upn
            Id                = $user.Id
            Department        = $Department
            Groups            = @($Config.DepartmentGroups[$Department], $Config.LicenseGroup)
            TemporaryPassword = ConvertTo-SecureString $password -AsPlainText -Force
        }
    }
}
