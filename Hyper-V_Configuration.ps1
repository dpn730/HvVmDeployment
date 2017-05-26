Configuration Hyper-V_Configuration
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xHyper-V

    $gigabyte = 1073741824

    #$AllNodes.ForEach({
    
        Node $AllNodes.Where{$_.NodeName -eq 'localhost'}.NodeName {
            $NodeName = $Node.NodeName
            $VmData = $Node.VmData
            foreach($Vm in $VmData) {
                Write-Host $Vm
                $VmName = $Vm.vmName
                $DestPath = $Vm.destPath
                $OsVhd = $Vm.osVHD
                $OsVersion = $Vm.osVersion                
                $VmSwitch = $Vm.vSwitchName
                $Memory = $Vm.memory
                $CPU = $Vm.vCpu
                $VlanId = $Vm.vlanID

                # unattend.xml Variables
                $VmIp = $Vm.vmIP
                $VmSubnetMask = Convert-RvNetSubnetMaskClassesToCidr $Vm.vmSubnetMask
                $Gateway = $Vm.gateway
                $DnsIp1 = $Vm.dnsIP1

                $newSystemVHDFolder = "$($DestPath)\$($VmName)"
                $newSystemVHDPath = "$($newSystemVHDFolder)\$($VMName)_OS.vhdx"

                File "$($NodeName)_$($VmName)_Folder" {
                    Type = 'Directory'
                    DestinationPath = $newSystemVHDFolder
                    Ensure = 'Present'
                }

                # Generate content of the unattend.xml from the template
                $sourceUnattendXmlContent = Get-Content "$(Split-Path -parent $PSCommandPath)\templates\unattend_$($OsVersion).xml"
                $sourceUnattendXmlContent = $ExecutionContext.InvokeCommand.ExpandString($sourceUnattendXmlContent)
                $newUnattendXmlPath = "$($newSystemVHDFolder)\unattend.xml"

                File "$($NodeName)_$($VmName)_UnattendedFile" {
                    Ensure = "Present"
                    Type = "File"
                    DestinationPath = $newUnattendXmlPath
                    Contents = [string] $sourceUnattendXmlContent
                    DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
                }
                
                File "$($NodeName)_$($VmName)_SystemDisk" {
                    SourcePath = "$OsVhd"
                    DestinationPath = $newSystemVHDPath      
                    Type = "File"
                    Ensure = "Present"
                    DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
                }                
                
                xVhdFile "$($NodeName)_$($VmName)_CopyUnattendxml"
                {
                    VhdPath =  $newSystemVHDPath
                    FileDirectory =  MSFT_xFileDirectory {
                                    SourcePath = $newUnattendXmlPath
                                    DestinationPath = "\Windows\Panther\unattend.xml"
                                }
                    DependsOn = "[File]$($NodeName)_$($VmName)_SystemDisk","[File]$($NodeName)_$($VmName)_UnattendedFile"
                }
                
                xVMHyperV "$($NodeName)_$($VmName)_NewVM"
                {
                    Ensure          = 'Present'
                    Name            = $VmName
                    VhdPath         = $newSystemVHDPath
                    SwitchName      = $VmSwitch
                    State           = "Off"
                    Path            = $newSystemVHDFolder
                    Generation      = 2
                    StartupMemory   = $([int] $Memory * $gigabyte)
                    ProcessorCount  = $CPU
                    RestartIfNeeded = $true
                    WaitForIP       = $WaitForIP 
                    DependsOn       = "[File]$($NodeName)_$($VmName)_SystemDisk","[xVhdFile]$($NodeName)_$($VmName)_CopyUnattendxml"
                }

                Script "$($NodeName)_$($VmName)_VlanID"
                {
                    SetScript = { 
                        Set-VMNetworkAdapterVlan -VMNetworkAdapterName  "Network Adapter"  -VMName $using:VmName -Access -VlanId $using:VlanId
                    }
                    TestScript = {
                        if($(Get-VMNetworkAdapterVlan -VMNetworkAdapterName "Network Adapter" -VMName $using:VmName).AccessVlanId -ne $using:VlanId) {
                            return $false
                        }
                        else {
                            return $true
                        }
                    }
                    GetScript = {
                        $(Get-VMNetworkAdapterVlan -VMNetworkAdapterName "Network Adapter" -VMName $using:VmName).AccessVlanId
                    }
                    DependsOn = "[xVMHyperV]$($NodeName)_$($VmName)_NewVM"         
                }

                Script "$($NodeName)_$($VmName)_DynamicMemory"
                {
                    SetScript = { 
                        Set-VMMemory -VMName $using:VmName -DynamicMemoryEnabled $false
                    }
                    TestScript = {
                        return !($(Get-VMMemory -VMName "$($using:VmName)").DynamicMemoryEnabled)
                    }
                    GetScript = {
                        $(Get-VMMemory -VMName $using:VmName).DynamicMemoryEnabled
                    }
                    DependsOn = "[xVMHyperV]$($NodeName)_$($VmName)_NewVM"         
                }
                
            }
        }
    #})
}