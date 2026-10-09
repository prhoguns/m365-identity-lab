@{
    # New-M365LabPassword makes a password; the rule is meant for functions that accept one as plain text.
    ExcludeRules = @('PSAvoidUsingConvertToSecureStringWithPlainText')
}
