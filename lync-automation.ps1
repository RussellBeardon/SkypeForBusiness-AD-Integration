<#
lynx-automation.ps1

Version 1.1
Version 1.2 added log file

automate lync/SFB tasks. Run this script on a Skype for business server as a scheduled task.

Users are not autmatically disabled in Skype when an AD user is set to disabled.
This could lead to a user being able to use their Skype login to make calls even after they have
left the company.

1. auto add users when user added to AD group
  enable a default skype user when a user is added to a skype group
2. auto remove users when user remove from AD group
  disable the skype user when the user is no longer a member of the skype AD group
3. email confirmation of actions
 
  create users with:
    -no conferencing
    -email address is skype kings username


#>
$ErrorActionPreference = "Stop";
$logDir = ($PSScriptRoot + "\logs\")
$logFile =($logDir + "lync.automation." + (get-date -Format yyyy-MM-dd) + ".txt")

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

# get skype AD group members
$ADGroupMembers = get-ADGroupMember $ADGroup -recursive

# get registered skype users
$enabledSkypeUsers = Get-CsAdUser -ResultSize Unlimited | Where-Object {$_.Enabled}

#compare skype ad group with skype registered users
$differences = diff $ADGroupMembers $enabledSkypeUsers -property 'samAccountName'

############# FUNCTIONS ################

function check-log {
  if(!(test-path $logFile)) {
    if(!(test-path $logDir)){
     # create directory
      new-item -path $logDir -type Directory | out-null
    }
    # create file
    new-item -path $logFile -type File | out-null
  }
}

function log-entry($message) {
  $timestamp = get-date -format o
  $entry = ($timestamp + " :: " + $message)
  add-content -path $logFile -value $entry
  write-host $entry
}

############ ACTIONS ###################

try {

  check-log
  # add or remove skype users
  if($differences) {
    log-entry "User mismatched - action required.."

    foreach($difference in $differences) {     # user enabled in skype but not in skype AD group
      $user = get-aduser $difference.samAccountName
      if($difference.Sideindicator -eq '=>') {
        # disable skype account
        Get-CsAdUser $user.userPrincipalName | disable-CSUser
        log-entry ($user.userPrincipalName + " Skype account disabled")
        # send email to helpdesk confirming change
        Send-MailMessage -from $mailFrom -to $mailTo -SmtpServer $mailServer -subject ($difference.samAccountName + " skype account disabled") -body ($difference.samAccountName + " skype account disabled via automated task on computer " + $hostname )

      } elseif($difference.SideIndicator -eq '<=') {      # user is AD group but is not an enabled Skype user
        # enable skype account
        enable-csuser -Identity $user.userPrincipalName -SipAddressType "EmailAddress" -SipDomain $skypeDomain -RegistrarPool $skypeRegistrarPool
        log-entry ($user.userPrincipalName + " skype account enabled.")
        # wait for user to be enabled
        start-sleep 60 
        # get user and set conferencing policy
        get-csuser $user.userPrincipalName | Grant-CsConferencingPolicy -PolicyName $skypeConferencePolicy
        log-entry ($user.userPrincipalName + " set conference policy: " + $skypeConferencePolicy)
        # send email to helpdesk confirming change
          Send-MailMessage -from $mailFrom -to $mailTo -SmtpServer $mailServer -subject ($difference.samAccountName + " skype account enabled") -body ($difference.samAccountName + " skype account enabled via automated task on computer " + $hostname )
      }
    }
  } else {
    log-entry "no changes required"
  }
  log-entry "script complete - no errors detected"
}
catch {
  $exception =  $_.Exception
  $line = $_.InvocationInfo.ScriptLineNumber
  log-entry ("ERROR: " + $exception.message + ": LINE: " + $line)
  Send-MailMessage -From $mailFrom -To $mailTo -Subject "lync-automation.ps1 script failure" -SmtpServer $mailServer -body ($hostname + " recorded an error on an automated task: " + $exception.message + ". LINE: " + $line)
  Break
}
