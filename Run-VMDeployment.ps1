param (

    [Parameter(Mandatory)]
    [ValidateScript({Test-Path -Path $_})]
    [string] $InputFilePath = '.\input\localhost.csv'
)

if (!(Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\xHyper-V')) {
    Write-Host "ERROR: In order to execute this script, xHyper-V module must be installed in the system." -ForegroundColor Red
    Break
}

$inputCsv = Import-Csv $InputFilePath

$MyConfig = 
@{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            VmData = $inputCsv
        }
    )
}

.'.\lib\Convert-RvNetIpAddressToInt64.ps1'
.'.\DeployVM.ps1'

DeployVM -ConfigurationData $MyConfig


Start-DscConfiguration -Wait -Force -Verbose -ComputerName localhost -Path $PSScriptRoot\DeployVM