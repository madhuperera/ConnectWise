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
$ListOfDevicesToUpdate = Import-Csv -Path $CSV_File_Path

# Update the Code to make changes to the Date Format to what is required by ConnectWise
function Set-CWDateUS
{
    param
    (        
        [String] $DateToChange
    )

    [string] $NewDate = ""

    $tmpCatcher = $DateToChange -split "/"
    $month = $tmpCatcher[0]
    if ($month.Length -eq 1)
    {
        $month = "0" + $month
    }
    $NewDate = -join ($tmpCatcher[2],"-",$month,"-",$tmpCatcher[1])
    
    return $($NewDate + "T00:00:00Z")
}

# New Object to store Duplicate Data
$DuplicateDevices = @()

[int] $CurrentItem = 1
$TotalItemCount = $ListOfDevicesToUpdate.count
foreach ($Device in $ListOfDevicesToUpdate)
{
    Write-Host "-------------------------------- $CurrentItem out of $TotalItemCount --------------------------------" -ForegroundColor Green
    $CWM_Config_ID = $Device.Configuration_RecId

    # Checking to see if ther are duplicates
    if (($ListOfDevicesToUpdate | Where-Object {$_.Configuration_RecId -eq "$($Device.Configuration_RecId)"}).count -gt 1)
    {
        Write-Host "Error: Configuration ID: $CWM_Config_ID is a duplicate within CSV" -ForegroundColor Red

        $NewDuplicate = @{
            'Audit_Value' = $Device.Audit_Value;
            'Date_Purchased' = $Device.Date_Purchased;
            'Audit_Token' = $Device.Audit_Token;
            'Config_Name' = $Device.Config_Name;
            'Configuration_RecId' = $Device.Configuration_RecId
        }
        $PSObject = New-Object -TypeName PSObject -Property $NewDuplicate
        $DuplicateDevices += $PSObject
    }
    else
    {
        $CWM_NewPurchaseDate = Set-CWDateUS -DateToChange $($Device.Audit_Value)

        Write-Host "Configuration ID: $CWM_Config_ID" -ForegroundColor White
        Write-Host "Configuration Name: $($Device.Config_Name)" -ForegroundColor White
        Write-Host "Configuration Purchase Date: $($Device.Audit_Value) ----> $CWM_NewPurchaseDate" -ForegroundColor White

        $CWM_GET_URI = "$($CWM_API_Base_URL)/company/configurations/$CWM_Config_ID" # Creating the URI for the given ID
        $CWM_Current_Device = Invoke-restmethod -headers $Header -method GET -uri $CWM_GET_URI # Retrieving the Configuration

        if ($CWM_Current_Device.count)
        {
            Write-Host "Error: We found two devices with the same configuration ID" -ForegroundColor Red
        }
        else
        {
            [string] $CWM_Current_DevicePDate = ($CWM_Current_Device.purchaseDate -split "T")[0]
            if ($CWM_Current_DevicePDate -like "*$($CWM_NewPurchaseDate)*" )
            {
                Write-Host "Already up to date: $CWM_NewPurchaseDate is as same as $($CWM_Current_Device.purchaseDate)" -ForegroundColor Yellow
            }
            else
            {
                Write-Host "Configuration will be updated to replace $($CWM_Current_Device.purchaseDate) with $CWM_NewPurchaseDate" -ForegroundColor Red
                
                $CWM_PATCH_BODY = '[{"op": "replace", "path": "purchaseDate", "value": "' + $CWM_NewPurchaseDate + '"}]' # Operation Set to "replace" the purchase date
                $CWM_PATCH_URI = "$($CWM_API_Base_URL)/company/configurations/$CWM_Config_ID" # Creating the URI for the given ID

                try
                {
                    $Results = Invoke-restmethod -headers $Header -method PATCH -uri $CWM_PATCH_URI -Body $CWM_PATCH_BODY
                }
                catch
                {
                    Write-Host "Error: Trying to update" -ForegroundColor Red
                    Write-Host "$_.Exception"
                }

                Write-Host "Configuration was successfully updated $($Results.purchaseDate) <--> $CWM_NewPurchaseDate" -ForegroundColor Green
            }
        }
    } 
    $CurrentItem += 1
}

Write-Host "-------------------------------- Duplicate Devices --------------------------------" -ForegroundColor Yello
$DuplicateDevices | Select-Object Audit_Value, Date_Purchased, Audit_Token, Config_Name, Configuration_RecId