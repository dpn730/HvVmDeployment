Configuration xVMNetworkAdapterVlanId {
    param (
        [string] $NodeName = 'localhost',

        [Parameter(Mandatory)]
        [string] $VmName,

        [ValidateNotNullOrEmpty()]
        [string] $VmNetworkAdapterName,

        [Parameter(Mandatory)]
        [string] $VlanId
    )

    Script "$($NodeName)_$($VmName)_VlanID" {
        SetScript = { 
            $vNic = Get-VMNetworkAdapter -VMName $using:VmName -Name $using:VmNetworkAdapterName
            if($vNic) {
                $vNic | Set-VMNetworkAdapterVlan -Access -VlanId $using:VlanId
            }
        }
        TestScript = {   
            $targetVnic = Get-VMNetworkAdapter -VMName $using:VmName -Name $using:VmNetworkAdapterName

            if($targetVnic) {
                if($($targetVnic | Get-VMNetworkAdapterVlan).AccessVlanId -ne $using:VlanId) {
                    Write-Host "Vlan ID of $($targetVnic.Name) for $($using:VmName) is not $($using:VlanId)"
                    return $false
                }
                else {
                    Write-Host "Vlan ID of $($targetVnic.Name) for $($using:VmName) is already $($using:VlanId)"
                    return $true
                }
            }
        }
        GetScript = {
            $targetVnic = Get-VMNetworkAdapter -VMName $using:VmName -Name $using:VmNetworkAdapterName
            
            if($targetVnic) {
                return $($targetVnic | Get-VMNetworkAdapterVlan).AccessVlanId
            }
            else {
                return $null
            }
        }       
    } 
}