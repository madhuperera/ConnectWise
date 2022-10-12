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
    [String] $DRMM_API_URL = "https://syrah-api.centrastage.net",
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
# Going through each device in Datto Site. 
# _______________________________________________________________________________________________________________________________________________________________________________

[int] $TotalDeviceCount = $DattoDevices.count
[int] $Current_Device_Count = 1
foreach ($DDevice in $DattoDevices)
{
    Write-Host "`n`n$($DDevice.hostname) -------------------------------- $Current_Device_Count out of $TotalDeviceCount" -ForegroundColor Yellow
    if ($DDevice.portalUrl)
    {
        [String] $ManagementLink = $DDevice.portalUrl
        [String] $NewCW_URI = ""
        
        
        $NewCW_URI = "$($CWM_API_Base_URL)/company/configurations?conditions=managementLink='$($ManagementLink)'"
        $CWM_Device = Invoke-restmethod -headers $Header -method GET -uri $NewCW_URI
        $CWM_DattoDevice = $CWM_Device | Where-Object {$_.type.name -like "Datto*"}
        
        if ($CWM_DattoDevice)
        {
            if ($CWM_DattoDevice.name -ne $DDevice.hostname)
            {
                Write-Host "$($DDevice.hostname) -------------------------------- Name in CW is $($CWM_DattoDevice.name) and Name in Datto is $($DDevice.hostname), please fix." -ForegroundColor DarkYellow
            }
        }
        else 
        {
            Write-Host "$($DDevice.hostname) -------------------------------- No Datto Variant in ConnectWise. This device is probably missing in ConnectWise" -ForegroundColor DarkRed
        }
        
    }
    else
    {
        Write-Host "$($DDevice.hostname) -------------------------------- No Management Link Found. This device is probably missing in ConnectWise." -ForegroundColor DarkRed
    }

    $Current_Device_Count += 1
}
