# SkypeForBusiness-AD-Integration
enable and disable Skype for Business user using an AD group.

Script is designed to be run as ascheduled task to automated adding and removing Skype users.

Edit the variables in this script to customise it for your own environment:

# email settings
$mailserver = ""
$mailFrom = ""
$mailTo = ""
$hostname = $env:computername

# skype AD group
$ADGroup = "SkypeUsers"
$skypeDomain = ""
$skypeRegistrarPool = ""
$skypeConferencePolicy = "Conferencing Disabled"
