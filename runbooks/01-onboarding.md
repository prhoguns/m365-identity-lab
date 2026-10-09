# Onboarding a new hire

**Trigger:** HR sends the new-hire row (first name, last name, department, job title) at least 3 business days before the start date.

1. Check the department exists in `DepartmentGroups` in `config/lab.local.psd1`. If not, ask the department manager which access the role needs before adding a mapping. Never copy another user's groups.
2. Preview: `Import-Csv new-hires.csv | New-M365LabUser -WhatIf`. Confirm UPNs, departments and groups.
3. Run without `-WhatIf`. Licences come from `LIC-M365-Standard` (group-based licensing), so there is no SKU to assign by hand.
4. Deliver the temporary password **to the manager by phone or in person**. Never by email or chat, and never to the new account's own mailbox. The password must be changed at first sign-in.
5. On day one, the user signs in, changes the password and registers Microsoft Authenticator at https://aka.ms/mysecurityinfo. Check `Get-M365LabMfaGap` the next day: anyone still listed gets a call.
6. Close the ticket with the UPN and the groups added (from the command output). Do not paste the password into the ticket.
