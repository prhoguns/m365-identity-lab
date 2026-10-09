# Lost or stolen device

1. Get the device from the user's name: Intune admin centre **Devices > All devices**, search the user.
2. **Company laptop:** start **Wipe** if it may contain data and is not BitLocker-encrypted, otherwise **Retire** after confirming encryption in the device's hardware page. Then revoke the user's sessions (Entra: **Users > Revoke sessions**) and reset their password if it may have been stored on the device.
3. **Personal phone (enrolled):** **Retire** removes company data and the work profile and leaves personal data alone. Do not full-wipe a personal device without the owner's written consent.
4. Devices that stop checking in show up in `Get-M365LabNonCompliantDevice -StaleSyncDays 14` before anyone reports them lost; review that list weekly.
5. Record the device, the action taken and when, in the ticket. For a stolen device, give the user the ticket number for their police report.
