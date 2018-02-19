Configuration xVMSwitchVlanId {
    param (
        [string] $NodeName = 'localhost',

        [Parameter(Mandatory)]
        [string] $VmName,

        [ValidateNotNullOrEmpty()]
        [string] $VmSwitchName,

        [ValidateNotNullOrEmpty()]
        [string] $VmNetworkAdapterName,

        [Parameter(Mandatory)]
        [string] $VlanId
    )

    Script "$($NodeName)_$($VmName)_VlanID" {
        SetScript = { 
            foreach($vNic in $(Get-VMNetworkAdapter -VMName $using:VmName)) {
                if($vNic.SwitchName -eq $using:VmSwitchName) {
                    $vNic | Set-VMNetworkAdapterVlan -Access -VlanId $using:VlanId
                }
            }
        }
        TestScript = {
            $targetVnic = $null
            foreach($vNic in $(Get-VMNetworkAdapter -VMName $using:VmName)) {
                if($vNic.SwitchName -eq $using:VmSwitchName) {
                    $targetVnic = $vNic
                }
            }

            if($targetVnic -ne $null) {
                if($($targetVnic | Get-VMNetworkAdapterVlan).AccessVlanId -ne $using:VlanId) {
                    Write-Host "Vlan ID of $($using:targetVnic.Name) for $($using:VmName) is not $($using:VlanId)"
                    return $false
                }
                else {
                    Write-Host "Vlan ID of $($using:targetVnic.Name) for $($using:VmName) is already $($using:VlanId)"
                    return $true
                }
            }
            else {
                Write-Host "A Network Adapter could not be found for $($using:VmSwitchName) on $($using:VmName)"
                return $true
            }
        }
        GetScript = {
            $targetVnic = $null
            foreach($vNic in $(Get-VMNetworkAdapter -VMName $using:VmName)) {
                if($vNic.SwitchName -eq $using:VmSwitchName) {
                    $targetVnic = $vNic
                }
            }
            return $($targetVnic | Get-VMNetworkAdapterVlan).AccessVlanId
        }       
    } 
}