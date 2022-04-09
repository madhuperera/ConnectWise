[CmdletBinding()]
param (
    [Parameter()]
    [String] $CWM_Client_ID,
    [Parameter()]
    [String] $CWM_Public_Key,
    [Parameter()]
    [String] $CWM_Private_Key,
    [Parameter()]
    [String] $CWM_Company_ID,
    [Parameter()]
    [String] $CWM_API_Base_URL = "https://aus.myconnectwise.net/v4_6_release/apis/3.0"
)


$Base64Key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$($CWM_Company_ID)+$($CWM_Public_Key):$($CWM_Private_Key)"))
$Header = @{
    'clientId'      = $CWM_Client_ID
    'Authorization' = "Basic $Base64Key"
    'Content-Type'  = 'application/json'
}


# ____________________________________________________________________

$Configurations += invoke-restmethod -headers $Header -method GET -uri "$($CWM_Client_ID)/company/configurations?pageSize=1000&page=$i"
$DattoLaptops = Invoke-restmethod -headers $Header -method GET -uri "$($CWM_API_Base_URL)/company/configurations?conditions=type/name='Datto Laptop'&pageSize=1000&page=$i"

# How to update Warranty Details
$X = '[{"op": "add", "path": "warrantyExpirationDate", "value": "2022-04-07T05:13:57Z"}]'
Invoke-restmethod -headers $Header -method PATCH -uri "$($CWM_API_Base_URL)/company/configurations/5606" -Body $X

$NewX = '[{"op": "replace", "path": "warrantyExpirationDate", "value": "2020-01-10T00:00:00Z"}]'
Invoke-restmethod -headers $Header -method PATCH -uri "$($CWM_API_Base_URL)/company/configurations/5606" -Body $NewX

$DattoDevices

foreach ($DDevice in $DattoDevices)
{
    Write-output "`n`n ------------------- $($DDevice.hostname) --------------------------------"
    if ($DDevice.warrantyDate)
    {
        [String] $ManagementLink = $DDevice.portalUrl
        [String] $NewCW_URI = ""
        if ($ManagementLink)
        {
            #$ManagementLink
            $NewCW_URI = "$($CWM_API_Base_URL)/company/configurations?conditions=managementLink='$($ManagementLink)'"
            #$NewCW_URI
            $CWM_Device = Invoke-restmethod -headers $Header -method GET -uri $NewCW_URI
            if ($CWM_Device.warrantyExpirationDate)
            {
                #[String] $CWM_WarrantyExpiryDate = $CWM_Device.warrantyExpirationDate.toString()
                #Write-Output "Warranty is already set... $($CWM_Device.name) | $CWM_WarrantyExpiryDate"
                Write-Output "Warranty is already set... $($CWM_Device.name)"
                
            }
            else
            {
                Write-Output "No Warranty $($CWM_Device.name)"
                [String] $CWM_DeviceWarrantyDate = ""
                $CWM_DeviceWarrantyDate = $DDevice.warrantyDate + "T00:00:00Z"
                $CWM_DeviceWarrantyDate
                $CWM_API_BodyWithWarranty = '[{"op": "add", "path": "warrantyExpirationDate", "value": "' + $CWM_DeviceWarrantyDate + '"}]'
                $CWM_API_BodyWithWarranty

                [String] $CWM_DeviceID = $CWM_Device.id
                $NewCWM_DeviceUpdateLink = "$($CWM_API_Base_URL)/company/configurations/$CWM_DeviceID"
                $NewCWM_DeviceUpdateLink

                Invoke-restmethod -headers $Header -method PATCH -uri $NewCWM_DeviceUpdateLink -Body $CWM_API_BodyWithWarranty
            }
            
        }
        else
        {
            Write-Output "Missing Management Link from Datto"    
        }
    }
    else
    {
        Write-Output "No Warranty in Datto for $(DDevice.hostname)"   
    }
}
