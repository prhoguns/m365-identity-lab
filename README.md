# Microsoft 365 Identity and Device Lab

[![CI](https://github.com/prhoguns/m365-identity-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/prhoguns/m365-identity-lab/actions/workflows/ci.yml)

Day-to-day Microsoft 365 administration as a PowerShell module over Microsoft Graph: onboarding and
offboarding, the reports a service desk runs every week, and Entra ID Conditional Access and Intune
compliance policies kept as code. It comes with the runbooks a help desk follows around it.

**Stack:** PowerShell 7, Microsoft Graph PowerShell SDK 2.41, Entra ID, Intune, Pester 6, PSScriptAnalyzer.

| | Command | What it does |
|---|---|---|
| Onboarding | `Import-Csv data/new-hires.csv \| New-M365LabUser` | Account, random temporary password that must be changed at first sign-in, department group, licence by group membership |
| Offboarding | `Disable-M365LabUser -UserPrincipalName ... -Reason ...` | Block sign-in, revoke sessions, scramble the password, remove groups and licences, write an audit record of what was removed |
| Stale accounts | `Get-M365LabStaleUser -Days 90` | Enabled accounts with no successful sign-in for 90 days, or never used |
| MFA gaps | `Get-M365LabMfaGap` | Users who cannot do MFA, or only by SMS or voice, administrators first |
| Devices | `Get-M365LabNonCompliantDevice` | Noncompliant devices, and devices that stopped checking in |
| Conditional Access | `Publish-M365LabConditionalAccess [-Enforce]` | Deploys [`policies/conditional-access/`](policies/conditional-access/) |
| Intune compliance | `Publish-M365LabCompliancePolicy` | Deploys and assigns [`policies/intune/`](policies/intune/) |

## Safety built in

- **`-WhatIf` everywhere.** Every command that changes the tenant previews its plan first. A test checks
  the preview counts what would really be removed.
- **Conditional Access can't lock everyone out.** A policy that does not exclude the break-glass group is
  refused before anything is sent. Policies are created in **report-only** mode; `-Enforce` is a
  separate, deliberate step after reading the sign-in logs ([runbook](runbooks/05-conditional-access-rollout.md)).
- **Reversible offboarding.** The account is disabled, not deleted, and the audit log lists every group
  and licence removed, so a mistaken offboarding can be undone.
- **Least privilege.** `Connect-M365Lab -ReadOnly` requests only read scopes for the reports.
- **No passwords in tickets or email.** Temporary passwords come back as `SecureString` for delivery by
  phone ([runbook](runbooks/01-onboarding.md)).

## Policies

| Policy | Applies to | Control |
|---|---|---|
| CA01 Require MFA for all users | Everyone except break-glass | MFA |
| CA02 Block legacy authentication | Everyone except break-glass; Exchange ActiveSync and other legacy clients | Block |
| CA03 Admin roles require MFA and a compliant device | Nine privileged directory roles | MFA **and** compliant device |
| Windows baseline compliance | `SEC-Intune-Users` | Windows 11 24H2+, BitLocker, Secure Boot, code integrity, firewall, Defender with real-time protection |
| iOS baseline compliance | `SEC-Intune-Users` | iOS 18+, 6-digit non-simple passcode, 5-minute lock, not jailbroken |

## Runbooks

[Onboarding](runbooks/01-onboarding.md) · [Offboarding](runbooks/02-offboarding.md) ·
[Password and MFA reset, with caller verification](runbooks/03-password-and-mfa-reset.md) ·
[Lost or stolen device](runbooks/04-lost-device.md) · [Conditional Access rollout](runbooks/05-conditional-access-rollout.md)

## Tests

`Invoke-Pester ./tests` runs 44 tests in CI against **mocked** Microsoft Graph cmdlets. The mocks wrap
the real SDK cmdlets, so a wrong cmdlet or parameter name fails the test. They cover:

- UPN collisions, accent handling and password strength.
- Offboarding order, its audit record and its `-WhatIf` preview.
- Report filtering.
- The break-glass refusal, report-only default, idempotent updates, and policy assignment.

Every policy file and script is also checked: valid structure, break-glass exclusion, Intune's
required block action, and no PSScriptAnalyzer warnings.

## Live tenant

Not yet run against a live tenant. Results from a Microsoft 365 trial tenant will be added here.

## Use it

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Users.Actions, `
  Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Reports, Microsoft.Graph.DeviceManagement -Scope CurrentUser
Copy-Item config/lab.psd1 config/lab.local.psd1    # then set your domain and group names
Import-Module ./M365Lab/M365Lab.psd1
Connect-M365Lab -UseDeviceCode                      # you sign in; nothing is stored
Import-Csv data/new-hires.csv | New-M365LabUser -WhatIf
```

Needs Entra ID P1 (Conditional Access, sign-in activity) and Intune, both included in Microsoft 365
Business Premium and E3/E5. The sample new hires in `data/` are fictional.
