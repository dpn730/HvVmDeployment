param (
    [Parameter(Mandatory)] 
    [string] $HyperVHostName,
    [Parameter(Mandatory)]
    [ValidateScript({$(Test-Path -Path $_) -and $_.ToLower().EndsWith('.csv')})]
    [string] $VmDataFilePath
)

if (!(Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\xHyper-V')) {
    Write-Host "ERROR: In order to execute this script, xHyper-V module must be installed in the system." -ForegroundColor Red
    Break
}

$inputCsv = Import-Csv $VmDataFilePath
 


$MyConfig = 
@{
    AllNodes = @(
        @{
            NodeName = $HyperVHostName
            VmData = $inputCsv
        }
    )
}

.'.\lib\Convert-RvNetIpAddressToInt64.ps1'
.'.\Hyper-V_Configuration.ps1'

Hyper-V_Configuration -ConfigurationData $MyConfig


Start-DscConfiguration -Wait -Force -Verbose -ComputerName localhost -Path $PSScriptRoot\Hyper-V_Configuration