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

    # All Datto RMM Parameters
    [Parameter()]
    [String] $DRMM_API_URL,
    [Parameter()]
    [String] $DRMM_Private_Key,
    [Parameter()]
    [String] $DRMM_Secret_Key,
    [Parameter()]
    [String] $DRMM_Client_Site_Name
)

# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Loading Datto RMM Module and authenticating to Datto Portal Online
# _______________________________________________________________________________________________________________________________________________________________________________

Write-Output "Constructing Datto Authentication Header and Loading Module"
$params = @{
    Url        =  $DRMM_API_URL
    Key        =  $DRMM_Private_Key
    SecretKey  =  $DRMM_Secret_Key
}
Import-Module DattoRmm
Set-DrmmApiParameters @params

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

# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Getting All Devices in Datto Site
# _______________________________________________________________________________________________________________________________________________________________________________

if ($DRMM_Client_Site_Name)
{
    $DattoSite = Get-DrmmAccountSites | Where-Object {$_.name -like "*$($DRMM_Client_Site_Name)*"}
    $DattoDevices = Get-DrmmSiteDevices -siteUid $($DattoSite.uid)
}
else
{
    $DattoDevices = Get-DrmmAccountDevices
}

# Filtering just for Desktops and Laptops
$DattoDevices = $DattoDevices | Where-Object {$_.deviceType.category -eq "Desktop" -or $_.deviceType.category -eq "Laptop"}

# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Going through each device in Datto Site. Finding devices with Warranty Expiration Dete and querying ConnectWise Manage API for the same device to see if Warranty Expiration 
# Date for the device in ConnectWise is configured. If not, update with the date froM Datto Device.
# _______________________________________________________________________________________________________________________________________________________________________________

[int] $TotalDeviceCount = $DattoDevices.count
[int] $Current_Device_Count = 1
foreach ($DDevice in $DattoDevices)
{
    Write-output "`n`n$($DDevice.hostname) -------------------------------- $Current_Device_Count out of $TotalDeviceCount"
    if ($DDevice.warrantyDate)
    {
        [String] $ManagementLink = $DDevice.portalUrl
        [String] $NewCW_URI = ""
        if ($ManagementLink)
        {
            $NewCW_URI = "$($CWM_API_Base_URL)/company/configurations?conditions=managementLink='$($ManagementLink)'"
            $CWM_Device = Invoke-restmethod -headers $Header -method GET -uri $NewCW_URI
            if ($CWM_Device.warrantyExpirationDate)
            {
                Write-Output "$($DDevice.hostname) -------------------------------- Warranty Expiration Date is already configured in ConnectWise"
                
            }
            else
            {
                Write-Output "$($DDevice.hostname) -------------------------------- Setting up Warranty Expiration Date in ConnectWise Manage"
                [String] $CWM_DeviceWarrantyDate = ""
                $CWM_DeviceWarrantyDate = $DDevice.warrantyDate + "T00:00:00Z"
                Write-Output "$($DDevice.hostname) -------------------------------- Date to Update is $CWM_DeviceWarrantyDate"
                
                $CWM_API_BodyWithWarranty = '[{"op": "add", "path": "warrantyExpirationDate", "value": "' + $CWM_DeviceWarrantyDate + '"}]'
                
                [String] $CWM_DeviceID = $CWM_Device.id
                $NewCWM_DeviceUpdateLink = "$($CWM_API_Base_URL)/company/configurations/$CWM_DeviceID"

                $Results = Invoke-restmethod -headers $Header -method PATCH -uri $NewCWM_DeviceUpdateLink -Body $CWM_API_BodyWithWarranty
                Write-Output "$($DDevice.hostname) -------------------------------- Successfully updated the date with $($Results.warrantyExpirationDate)"
            }
            
        }
        else
        {
            Write-Output "$($DDevice.hostname) -------------------------------- Missing Management Link from Datto!"    
        }
    }
    else
    {
        Write-Output "$($DDevice.hostname) -------------------------------- Warranty Expiration Date is missing in Datto!"   
    }

    $Current_Device_Count += 1
}
