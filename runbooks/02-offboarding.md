# Offboarding a leaver

**Trigger:** HR or the manager confirms the last day in the ticket. For an involuntary departure, offboard **during** the exit meeting, not after it.

1. Confirm the request comes from HR or the manager of record, not from a forwarded email.
2. Preview: `Disable-M365LabUser -UserPrincipalName <upn> -Reason '<ticket number>' -WhatIf`.
3. Run it. It blocks sign-in, revokes every refresh token (signing the user out of Outlook, Teams and phones within the hour), sets a random password, removes static group memberships (dropping group-based licences) and direct licences.
4. The audit record in `logs/offboarding.jsonl` lists every group and licence removed. Attach it to the ticket; it is how access is restored if the offboarding was a mistake.
5. Mailbox and OneDrive: the account is kept, not deleted, so the manager can be given access or the mailbox converted to shared. Delete the account after the retention period agreed with HR (deleted users can be restored for 30 days).
6. Ask the manager to return the laptop and phone. If a device is not returned, follow [04-lost-device.md](04-lost-device.md).
