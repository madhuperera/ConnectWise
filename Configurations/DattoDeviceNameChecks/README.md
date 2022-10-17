# Check for Datto Device Name Changes
You can use this script to get a list of devices in Datto RMM and compare them against the configurations in ConnectWise Manage to see if any device is missing or has a different name. 

I am sharing these scripts **"AS IS" without any kind of warranty**. Please go through the scripts' content before deploying in your environment.

If you have any question about any of the scripts or you have an idea for a PowerShell based script, please leave a comment.

## Setting up the Environment to run this Script
- Datto RMM PowerShell Module
- ConnectWise Manage APIs to retrieve Configurations
- Datto RMM APIs to retrieve Devices

### Datto RMM PowerShell Module
How to check if the current session has Datto RMM Module installed.
```
Get-InstalledModule DattoRmm
```
![image](https://user-images.githubusercontent.com/101617608/196299597-3c773f17-9d52-4fe8-acb2-f344a81a3bd6.png)

How to check the latest version available to download.
```
Find-Module DattoRmm
```
![image](https://user-images.githubusercontent.com/101617608/196299769-f51cf50d-1aa7-417c-8e0b-9b65ac226ce4.png)

How to install the PowerShell Module
```
Install-Module DattoRmm -Force
```
Please visit GitHub for more information [Datto RMM PowerShell Module](https://github.com/aaronengels/DattoRMM).

## Feedback
Constructive feedback is always appreciated. I am doing most of these Scripts in my own Personal time, so I will not be able to update these as often as I would have liked to. If you find any issues with the Scripts, please leave a comment and I will try my best to get it sorted and update the Script. If you have an idea for a Script that could be useful for yourself as well as others, you can contact me using any of the Social Media platforms below:
- [LinkedIn](https://www.linkedin.com/in/madhuperera/ "LinkedIn")
- [Twitter](https://twitter.com/madhu_perera "Twitter")
