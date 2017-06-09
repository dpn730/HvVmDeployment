param (
    [Parameter(Mandatory)] 
    [string] $HyperVHostName,
    [ValidateScript({$(Test-Path -Path $_) -and $_.ToLower().EndsWith('.csv')})]
    [string] $VmDataFilePath,
    [ValidateScript({$(Test-Path -Path $_) -and $_.ToLower().EndsWith('.csv')})]
    [string] $vSwitchFilePath
)

if (!(Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\xHyper-V')) {
    Write-Host "ERROR: In order to execute this script, xHyper-V module must be installed in the system." -ForegroundColor Red
    exit
}

# Import and convert VM data
$vmInputCsv = @()
if($PSBoundParameters.ContainsKey('VmDataFilePath')) {
    $vmInputCsv = Import-Csv $VmDataFilePath
    foreach($item in $vmInputCsv) {
        $dataDiskJson = $(ConvertFrom-Json $item.dataDisks).dataDisks
        $item.dataDisks = $dataDiskJson

        $ipConfigJson = $(ConvertFrom-Json $item.ipConfig).ipConfig
        $item.ipConfig = $ipConfigJson

        $dnsIpJson = $(ConvertFrom-Json $item.dnsIp).dnsIp
        $item.dnsIp = $dnsIpJson

        if($dnsIpJson.length -gt 4) {
            Write-Host "ERROR: $($item.VmName) cannot have more than 4 Dns Ips" -ForegroundColor Red
            exit
        }
    }
}

#Import and convert vSwitch data
$vSwitchInputCsv = @()
if($PSBoundParameters.ContainsKey('vSwitchFilePath')) {
    $vSwitchInputCsv = Import-Csv $vSwitchFilePath
}

$MyConfig = 
@{
    AllNodes = @(
        @{
            NodeName = $HyperVHostName
            VmData = $vmInputCsv
            vSwitchData = $vSwitchInputCsv
        }
    )
}


.'.\lib\Convert-RvNetIpAddressToInt64.ps1'
.'.\Hyper-V_Configuration.ps1'

Hyper-V_Configuration -ConfigurationData $MyConfig


Start-DscConfiguration -Wait -Force -Verbose -ComputerName $HyperVHostName -Path $PSScriptRoot\Hyper-V_Configuration
