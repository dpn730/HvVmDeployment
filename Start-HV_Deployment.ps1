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
 
foreach($item in $inputCsv) {
    $dataDiskJson = $(ConvertFrom-Json $item.dataDisks).dataDisks
    $item.dataDisks = $dataDiskJson

    $ipConfigJson = $(ConvertFrom-Json $item.ipConfig).ipConfig
    $item.ipConfig = $ipConfigJson

    $dnsIpJson = $(ConvertFrom-Json $item.dnsIp).dnsIp
    $item.dnsIp = $dnsIpJson
}

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


Start-DscConfiguration -Wait -Force -Verbose -ComputerName $HyperVHostName -Path $PSScriptRoot\Hyper-V_Configuration
