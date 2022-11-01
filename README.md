## AzureAD-PS-scripts

###Onboarding
```
./user_onboarding.ps1
-firstname <"First name of the new user">
-surname <"Last name of the new user">
-manager <"The user principle name (example.user@gmail.com) of the new users manager">
-upn_copy_profile <"The user principle name of another user in the organisation that the new user should copy the attributes of">
-country <"The country the user resides in. (AU, VN, IN)">
-jobtitle <"Job title the new user has been assigned">
-department <"The team/division the new user belongs to (eg Cloud and Technology)">

(Optional)

-office_location <"City the primary office is located"> (Melbourne)
-state <"The state the primary office is located"> (Vic)
-post_code <"The postal code the primary office is located"> (3000)
-$street_addr <"The street address of the primary office"> 
```

###Offboarding
```
./user_offboarding.ps1
-user <"User principle name of the offboarding user">
```
