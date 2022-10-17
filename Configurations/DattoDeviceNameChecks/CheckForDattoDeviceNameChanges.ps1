<#
.Description
This script will help you to get a list of Devices in Datto RMM and compare them to the Configurations in 
ConnectWise Manage for any missing device or a name mismatch.

This Script will require API with Read Only access to Configurations in ConnectWise Manage and 
Devices in Datto RMM.
.PARAMETER database
Coming Soon
.PARAMETER region
Coming Soon
.PARAMETER Comment
Coming Soon
.EXAMPLE
How to run the Script against one Datto RMM Site

PS> .\CheckForDattoDeviceNameChanges.ps1 -CWM_Client_ID <intentionally_left_blank> -CWM_Public_Key <intentionally_left_blank> 
-CWM_Private_Key -CWM_Company_ID <intentionally_left_blank> -DRMM_Private_Key <intentionally_left_blank> 
-DRMM_Secret_Key <intentionally_left_blank> -DRMM_Client_Site_Name "Test Site Name" -Report_Location "C:\Reports\"
.EXAMPLE
How to run the Script against All Datto RMM Sites

PS> .\CheckForDattoDeviceNameChanges.ps1 -CWM_Client_ID <intentionally_left_blank> -CWM_Public_Key <intentionally_left_blank> 
-CWM_Private_Key -CWM_Company_ID <intentionally_left_blank> -DRMM_Private_Key <intentionally_left_blank> 
-DRMM_Secret_Key <intentionally_left_blank> -Report_Location "C:\Reports\"
.SYNOPSIS
PowerShell Script to find out missing devices or the ones with different names in ConnectWise Manage.
#>
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
    [String] $DRMM_Client_Site_Name,
    [Parameter()]
    [bool] $DRMM_ExcludeOnDemandDevices = $false, # Reserved for future development

    # All Other Parameters
    [Parameter()]
    [String] $Report_Location # Ex: C:\Reports\
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

# Array to store devices for final CSV Report
$FinalDeviceArray = @()

foreach ($DDevice in $DattoDevices)
{
    # Variables to Manage Final Report
    [String] $Status = "All Good"
    [String] $NameInCW = ""
    [String] $DattoSiteName = $DDevice.siteName

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
            $NameInCW = $CWM_DattoDevice.name

            if ($CWM_DattoDevice.name -ne $DDevice.hostname)
            {
                $Status = "Name Mismatch"
                Write-Host "$($DDevice.hostname) -------------------------------- Name in CW is $($CWM_DattoDevice.name) and Name in Datto is $($DDevice.hostname), please fix." -ForegroundColor DarkYellow
            }
        }
        else 
        {
            $Status = "Missing in CW"
            Write-Host "$($DDevice.hostname) -------------------------------- No Datto Variant in ConnectWise. This device is probably missing in ConnectWise" -ForegroundColor DarkRed
        }
        
    }
    else
    {
        $Status = "Missing in CW"
        Write-Host "$($DDevice.hostname) -------------------------------- No Management Link Found. This device is probably missing in ConnectWise." -ForegroundColor DarkRed
    }


    # New Object to store all data
    $FinalDeviceProps = @{
        'DattoHostName' = $DDevice.hostname;
        'Status' = $Status;
        'Name in CW' = $NameInCW;
        'Site Name' = $DattoSiteName
    }
    $PSObject = New-Object -TypeName PSObject -Property $FinalDeviceProps
    $FinalDeviceArray += $PSObject

    $Current_Device_Count += 1
}

$FinalDeviceArray | Export-Csv -Path "$($Report_Location)AllDevices.csv" -NoTypeInformation