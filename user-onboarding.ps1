[cmdletbinding()]
param
(
    [parameter(Mandatory=$True)]
    [Alias("name")]
    [string]$firstname,

    [parameter(Mandatory=$True)]
    [string]$surname,

    [parameter(Mandatory=$True)]
    [string]$manager,

    [parameter(Mandatory=$False)]
    [string]$upn_copy_profile,

    [parameter(Mandatory=$False)]
    [ValidateSet("AU", "VN", "CN")]
    [string]$country = "AU",

    [parameter(Mandatory=$True)]
    [Alias("title")]
    [string]$jobtitle,

    [parameter(Mandatory=$True)]
    [string]$department,

    [parameter(Mandatory=$False)]
    [Alias("Office")]
    [string]$office_location = "Melbourne",

    [parameter(Mandatory=$False)]
    [string]$state = "Vic",

    [parameter(Mandatory=$False)]
    [Alias("zip")]
    [string]$post_code = "3000",

    [parameter(Mandatory=$False)]
    [string]$street_addr = "Level 16, 324 Collins Street"

)

function Set-User-Manager($manager_upn, $user_id) {
    <#Function is used to retrieve manager object id via its VPN, and also used to add manager to new user attribute#>
    $manager_id = (Get-AzureADUser -ObjectId $manager_upn).ObjectId
    Set-AzureADUserManager -ObjectId $user_id.ObjectId -RefObjectId $manager_id

    return $manager_id

}

function Get-Temp-Password {
    <#Generate a temporary password for new user. Return the password profile object back to calling function#>
    $password_profile_obj = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $password_obj = New-Object -TypeName PSObject
    $password_obj | Add-Member -MemberType ScriptProperty -Name "Password" -Value { ("@#$%^&0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray() | sort {Get-Random})[0..12] -join ''}
    $password_profile_obj.Password = $password_obj.Password

    return $password_profile_obj

}

function Set-User-Extended-Attributes($user_id) {
    <#Add other extended properties to user object#>
    Set-AzureADUser -ObjectId $user_id -PhysicalDeliveryOfficeName $office_location -City $office_location -StreetAddress $street_addr -PostalCode $post_code -TelephoneNumber "+61 3 8888 8888"

}

function Set-Group-List {
    <#Get Manager group list and prompt to add memebership to user. If custom list of groups provided at run-time, will add the user to those groups too#>
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory=$True)]
        [string]$profile_id,

        [parameter(Mandatory=$True)]
        [string]$new_user_id,

        [parameter(Mandatory=$False)]
        [string[]]$custom_groups
    )


    $profile_groups = Get-AzureADUserMembership -ObjectId $profile_id | Where-Object {$_.ObjectType -eq "Group"}
    $groups = @()
    foreach($profile_group in $profile_groups) {

        $group_instance = Get-AzureADMSGroup -Id $profile_group.ObjectId
        if($group_instance.GroupTypes -contains "DynamicMembership") {
            continue
        }

        else {
            $groups += $profile_group
        }
    }

    foreach($group in $groups) {
        if(($group.GroupTypes -notcontains "DynamicMembership") -and ($group.SecurityEnabled -eq $true) -and ($group.MailEnabled -eq $false)) {

            $confirmation = Read-Host "Would you like to add user to group: $($group.DisplayName) (y or n)"
            if($confirmation -in @("y", "yes", "Yes", "YES")) {

                Add-AzureADGroupMember -ObjectId $group.Id -RefObjectId $new_user_id
                continue
            }

            else {
                continue
            }
        }

        else {
            $confirmation = Read-Host "Would you like to add user to group: $($group.DisplayName) (y or n)"
            if($confirmation -in @("y", "yes", "Yes", "YES")) {
                try{
                    Add-UnifiedGroupLinks -Identity $group.ObjectId -LinkType Members -Links $new_user_id -Confirm:$false -ErrorAction Ignore}

                catch {
                    Add-DistributionGroupMember -Identity $group.ObjectId -Member $new_user_id -Confirm:$false -ErrorAction Ignore}
            }
        }
    }
}

#Global variables
$display_name = "$($firstname) $($surname)"
$upn = "$($firstname.ToString().ToLower()).$($surname.ToString().ToLower())@gmail.com"
$mail_nickname = "$($firstname.ToString().ToLower()).$($surname.ToString().ToLower())"

switch ($country)
{
    "AU" { $country_long = "Australia" }
    "VN" { $country_long = "Vietnam"   }
    "IN" { $country_long = "India"     }
}

#Generate password and display temp password in STDOUT. Convert to secure string to be passed to commandlet
$password = Get-Temp-Password
Write-Output $password.Password
$secure_string_pass = ConvertTo-SecureString -String $password.Password -AsPlainText -Force

#Creating new user, and ensure password is forced to be changed on successful login
$new_user_obj = New-AzureADUser -AccountEnabled $true -GivenName $firstname -Surname $surname -CompanyName "Company" -DisplayName $display_name -Department $department -JobTitle $jobtitle -UserPrincipalName $upn -UserType "Member" -PasswordProfile $password -UsageLocation $country -MailNickName $mail_nickname -State $state -Country $country_long -InformationAction Stop
Set-AzureADUserPassword -ObjectId  $new_user_obj.ObjectId -ForceChangePasswordNextLogin $true -Password $secure_string_pass
#Set manager, extended attributes and add to groups
$manager_obj_id = Set-User-Manager $manager $new_user_obj
Set-User-Extended-Attributes $new_user_obj.ObjectId
Start-Sleep -Seconds 10
if($upn_copy_profile) {
    Set-Group-List -profile_id $upn_copy_profile -new_user_id $new_user_obj.ObjectId
}
else {
    Set-Group-List -profile_id $manager -new_user_id $new_user_obj.ObjectId
}