# Password reset and MFA method reset

The help desk is the most common way into an account: an attacker who can talk a technician into a reset does not need the password. **Verify identity before every reset.**

## Verify the caller

1. Hang up and call back on the number in the HR directory, not the number they called from.
2. Or verify by video call against the photo on file, or ask the user's manager to confirm on a separate channel.
3. Never accept "I'm travelling and my phone was stolen, please remove MFA" on one call alone. That is the textbook social-engineering request. Escalate it to the security lead.

## Password reset

- Users with MFA registered reset their own password at https://aka.ms/sspr. Point them there first.
- Otherwise, in the Entra admin centre: **Users > the user > Reset password**, with **Require password change at next sign-in** left on. Read the temporary password to the verified user over the phone.

## Lost or replaced phone (MFA reset)

1. Verify identity as above (this is the higher-risk request).
2. Entra admin centre: **Users > the user > Authentication methods > Require re-register multifactor authentication**, and **Revoke sessions**.
3. Ask the user to register the new phone at https://aka.ms/mysecurityinfo while still on the call.
4. Note in the ticket how identity was verified.
