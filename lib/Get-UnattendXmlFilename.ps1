function Get-UnattendXmlFilename () {
    param (
        [ValidateScript({$(Test-Path -Path $_) -and $_.ToLower().EndsWith('.csv')})]
        [string] $UnattendRegistryFile = "$($PSScriptRoot)\..\templates\windows_unattend_registry.csv",
        [Parameter(Mandatory)]
        [string] $OsVersion,
        [Parameter(Mandatory)]
        [string] $OsEdition,
        [Parameter(Mandatory)]
        [bool] $DomainJoin
    )

    $returnValue = $null
    $registry = Import-Csv $UnattendRegistryFile
    foreach ($entry in $registry) {
        if($entry.osEdition -eq $OsEdition -and $entry.osVersion -eq $OsVersion `
            -and [System.Convert]::ToBoolean($entry.domainJoin) -eq $DomainJoin) {
                $returnValue = $entry.fileName
            }
    }

    return $returnValue
}