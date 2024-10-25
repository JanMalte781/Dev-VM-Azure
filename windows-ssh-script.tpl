add-content -path C:/Users/Jan/.ssh/config - value @'

Host ${hostname}
  Hostname ${hostname}
  User ${user}
  IdentityFile ${identityfile}
'@
