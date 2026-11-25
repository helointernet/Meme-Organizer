param (
    [string]$path
)
$ErrorActionPreference = "Stop"

$acl = Get-Acl $path
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Write, Delete", "Deny")
$acl.AddAccessRule($rule)

Set-Acl $path $acl