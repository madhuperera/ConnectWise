[CmdletBinding()]
param (

    # All ConnectWise Manage Parameters
    [Parameter()]
    [String] $CWM_Client_ID,
    [Parameter()]
    [String] $CWM_Public_Key,
    [Parameter()]
    [String] $CWM_Private_Key,
    [Parameter()]
    [String] $CWM_Company_ID,
    [Parameter()]
    [String] $CWM_API_Base_URL = "https://aus.myconnectwise.net/v4_6_release/apis/3.0",

    [Parameter()]
    [String] $CSV_File_Path
)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Preparing Header to Authenticate to ConnectWise Manage
# _______________________________________________________________________________________________________________________________________________________________________________

Write-Output "Constructing ConnectWise Manage Authentication Header"
$Base64Key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($CWM_Company_ID)+$($CWM_Public_Key):$($CWM_Private_Key)"))
$Header = @{
    'clientId'      = $CWM_Client_ID
    'Authorization' = "Basic $Base64Key"
    'Content-Type'  = 'application/json'
}


# Update the code to read the CSV into a variable


# Update the Code to make changes to the Date Format to what is required by ConnectWise

$CWM_Config_ID = "" # Change Me please
$CWM_NewPurchaseDate = "" # Please change Me: "2022-05-11T00:00:00Z"

$CWM_GET_URI = "$($CWM_API_Base_URL)/company/configurations/$CWM_Config_ID" # Creating the URI for the given ID
$CWM_Current_Device = Invoke-restmethod -headers $Header -method GET -uri $CWM_GET_URI # Retrieving the Configuration

# Update the code to confirm we are only looking at one configuration

# Update the code to match the Date Required to what is currently configured

$CWM_PATCH_BODY = '[{"op": "replace", "path": "purchaseDate", "value": "' + $CWM_DeviceWarrantyDate + '"}]' # Operation Set to "replace" the purchase date
$CWM_PATCH_URI = "$($CWM_API_Base_URL)/company/configurations/$ID" # Creating the URI for the given ID

$Results = Invoke-restmethod -headers $Header -method PATCH -uri $CWM_PATCH_URI -Body $CWM_PATCH_BODY # Updating the configuration with the new Body

# update the code to check if the Results match what was in the CSV