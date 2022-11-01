[cmdletbinding()]
param
(
    [parameter(Mandatory=$True)]
    [Alias("upn")]
    [string]$user

)


function Set-Inactive-User-Properties {
    <#Remove the attributes of user, that is used for dynamic group association#>
    Write-Host "Removing user properties from Azure AD......"
    Remove-AzureADUserManager -ObjectId $user
    $properties = [Collections.Generic.Dictionary[[String],[String]]]::new()
    $properties.Add("telephoneNumber", [NullString]::Value)
    $properties.Add("country", [NullString]::Value)
    $properties.Add("city", [NullString]::Value)
    $properties.Add("physicalDeliveryOfficeName", [NullString]::Value)
    $properties.Add("streetAddress", [NullString]::Value)
    $properties.Add("state", [NullString]::Value)
    $properties.Add("postalCode", [NullString]::Value)
    Set-AzureADUser -ObjectId $user -ExtensionProperty $properties
}


function Remove-User-Group-Membership-AzureAD {
    <#Remove static group association#>
    Write-Host "Removing user from Azure AD groups...."
    $user_id = (Get-AzureADUser -ObjectId $user).ObjectId
    $groups = Get-AzureADUserMembership -ObjectId $user_id | Where-Object {$_.ObjectType -eq "Group"}
    foreach($group in $groups) {
        $group_instance = Get-AzureADMSGroup -Id $group.ObjectId
        if(($group_instance.GroupTypes -notcontains "DynamicMembership") -and ($group_instance.SecurityEnabled -eq $true) -and ($group_instance.MailEnabled -eq $false)) {
            Remove-AzureADGroupMember -ObjectId $group.ObjectId -MemberId $user_id
        }
    }
}

#disables the user account
$confirmation = Read-Host "Are you sure you want to disable the user: $($user) (y or n)"
if($confirmation -in @("y", "yes", "Yes", "YES")) {
    Set-AzureADUser -ObjectId $user -AccountEnabled $false

}

else {
    Return
}

#Revokes all user sessions to Azure AD, and any applications using Azure AD as its identity provider
$userID = (Get-AzureADUser -ObjectId $user).ObjectId
Revoke-AzureADUserAllRefreshToken -ObjectId $userID

#functions called, used for parts of user offboarding
Set-Inactive-User-Properties
Remove-User-Group-Membership-AzureAD