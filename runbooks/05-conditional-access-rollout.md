# Rolling out a Conditional Access policy

Conditional Access can lock every user, including administrators, out of the tenant. Every change follows these steps.

0. **Licence and security defaults.** Conditional Access needs Entra ID P1 (Business Premium, E3/E5), and
   it replaces security defaults: the two cannot be on together. Build CA01 and CA02 in report-only first,
   then turn security defaults off in the same change window as enforcing them, never before.
1. **Break-glass first.** Two cloud-only emergency accounts with long random passwords stored offline, members of `SEC-BreakGlass-Excluded`, excluded from every policy. `Publish-M365LabConditionalAccess` refuses any policy that does not exclude that group.
2. **Report-only.** `Publish-M365LabConditionalAccess` creates policies as `enabledForReportingButNotEnforced`.
3. **Read the impact** for at least a week: Entra admin centre **Sign-in logs > Report-only** tab, or the Conditional Access insights workbook. Look for users and apps that *would have been blocked*.
4. **Clear the gaps.** `Get-M365LabMfaGap` lists users who cannot do MFA yet; get them registered before CA01 is enforced. Legacy-auth sign-ins seen under CA02 point at old mail clients or scanners to replace first.
5. **Enforce** with `Publish-M365LabConditionalAccess -Enforce`, at the start of a working day, with the help desk told in advance.
6. **Roll back** by publishing again without `-Enforce` (back to report-only), or sign in with a break-glass account if administrators are locked out.
