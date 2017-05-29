Configuration Hyper-V_Configuration
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xHyper-V

    $gigabyte = 1073741824

    $AllNodes.ForEach({
            Node $_.NodeName {
            $NodeName = $Node.NodeName
            $VmData = $Node.VmData
            
            WindowsFeature "$($NodeName)_Hyper-V"
            {
                Ensure = 'Present'
                Name   = 'Hyper-V'
            }
            
            WindowsFeature "$($NodeName)_Hyper-V-Powershell" {
                Ensure='Present'
                Name='Hyper-V-Powershell'
                DependsOn = "[WindowsFeature]$($NodeName)_Hyper-V"
            }            

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
                $DataVhdSize = $Vm.dataVHDSize
                $VmDependsOn = @()

                # unattend.xml Variables
                $VmIp = $Vm.vmIP
                $VmSubnetMask = Convert-RvNetSubnetMaskClassesToCidr $Vm.vmSubnetMask
                $Gateway = $Vm.gateway
                $DnsIp1 = $Vm.dnsIP1

                $newSystemVHDFolder = "$($DestPath)\$($VmName)"
                $osVHDPath = "$($newSystemVHDFolder)\$($VMName)_OS.vhdx"
                $dataVHDPath = "$($newSystemVHDFolder)\$($VMName)_DATA.vhdx"
                

                File "$($NodeName)_$($VmName)_Folder" {
                    Type = 'Directory'
                    DestinationPath = $newSystemVHDFolder
                    Ensure = 'Present'
                }

                File "$($NodeName)_$($VmName)_SystemDisk" {
                    SourcePath = "$OsVhd"
                    DestinationPath = $osVHDPath      
                    Type = "File"
                    Ensure = "Present"
                    DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
                }
                $VmDependsOn += "[File]$($NodeName)_$($VmName)_SystemDisk" 

                # Check if OS disk was already attached before attempting to copy unattend.xml
                if($(Test-Path -Path $osVHDPath) -and !($(Get-VHD $osVHDPath).Attached)){
                     
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
                    
                    xVhdFile "$($NodeName)_$($VmName)_CopyUnattendxml"
                    {
                        VhdPath =  $osVHDPath
                        FileDirectory =  MSFT_xFileDirectory {
                                        SourcePath = $newUnattendXmlPath
                                        DestinationPath = "\Windows\Panther\unattend.xml"
                                    }
                        DependsOn = "[File]$($NodeName)_$($VmName)_SystemDisk","[File]$($NodeName)_$($VmName)_UnattendedFile"
                    }

                    $VmDependsOn += "[xVhdFile]$($NodeName)_$($VmName)_CopyUnattendxml"
                }

                xVHD "$($NodeName)_$($VmName)_DataDisk"
                {
                    Ensure           = 'Present'
                    Name             = Split-Path $dataVHDPath -leaf
                    Path             = Split-Path $dataVHDPath
                    Generation       = 'vhdx'
                    MaximumSizeBytes = $([int] $DataVhdSize * $gigabyte)
                    DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
                }

                xVMHyperV "$($NodeName)_$($VmName)_NewVM"
                {
                    Ensure          = 'Present'
                    Name            = $VmName
                    VhdPath         = $osVHDPath
                    SwitchName      = $VmSwitch
                    State           = "Running"
                    Path            = $newSystemVHDFolder
                    Generation      = 2
                    StartupMemory   = $([int] $Memory * $gigabyte)
                    ProcessorCount  = $CPU
                    RestartIfNeeded = $true
                    WaitForIP       = $WaitForIP 
                    DependsOn       = $VmDependsOn
                }

                Script "$($NodeName)_$($VmName)_VlanID"
                {
                    SetScript = { 
                        Set-VMNetworkAdapterVlan -VMNetworkAdapterName  "Network Adapter"  -VMName $using:VmName -Access -VlanId $using:VlanId
                    }
                    TestScript = {
                        if($(Get-VMNetworkAdapterVlan -VMNetworkAdapterName "Network Adapter" -VMName $using:VmName).AccessVlanId -ne $using:VlanId) {
                            Write-Host "Vlan ID of 'Network Adapter' for $($using:VmName) is not $($using:VlanId)"
                            return $false
                        }
                        else {
                            Write-Host "Vlan ID of 'Network Adapter' for $($using:VmName) is already $($using:VlanId)"
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
                        Write-Host "$($using:VmName) dynamic memory enabled: $($(Get-VMMemory -VMName "$($using:VmName)").DynamicMemoryEnabled)"
                        return !($(Get-VMMemory -VMName "$($using:VmName)").DynamicMemoryEnabled)
                    }
                    GetScript = {
                        $(Get-VMMemory -VMName $using:VmName).DynamicMemoryEnabled
                    }
                    DependsOn = "[xVMHyperV]$($NodeName)_$($VmName)_NewVM"         
                }
                
                Script "$($NodeName)_$($VmName)_FormatDataDisk"
                {
                    SetScript = { 
                        Get-VHD -Path $using:dataVHDPath | Mount-VHD -Passthru `
                            | Initialize-Disk -Passthru | New-Partition -AssignDriveLetter -UseMaximumSize `
                            | Format-Volume -FileSystem NTFS -Confirm:$false -NewFileSystemLabel "$($using:VmName)_DATA" -Force

                        Dismount-VHD -Path $using:dataVHDPath -Confirm:$false
                    }
                    TestScript = {
                        $found = $false
                        if(!($(Get-VM $using:VmName).State -eq "Running" `
                                -and $(Get-VHD $using:dataVHDPath).Attached)) {                            
                            
                            Mount-VHD -Path $using:dataVHDPath -Confirm:$false -NoDriveLetter
                            $(Get-Volume).foreach({
                                if($_.FileSystemLabel -eq "$($using:VmName)_DATA") {
                                    Write-Host "$($using:dataVHDPath) has already been initialized."
                                    $found = $true
                                }
                            })
                            Dismount-VHD -Path $using:dataVHDPath -Confirm:$false
                        
                            if(!$found) {
                                Write-Host "$($using:dataVHDPath) has not been initialized."                                    
                            }                                
                        }
                        else {
                            Write-Host "$($using:dataVHDPath) has already been attached and $($using:VmName) is running, unable to mount VHD."
                            $found = $true
                        }

                        return $found
                    }
                    GetScript = {
                        return $(Get-VHD $using:dataVHDPath).Path
                    }
                    DependsOn = "[xVHD]$($NodeName)_$($VmName)_DataDisk"         
                }

                Script "$($NodeName)_$($VmName)_AttachDataDisk"
                {
                    SetScript = { 
                        Add-VMHardDiskDrive -VMName $using:VmName -Path $using:dataVHDPath
                    }
                    TestScript = {
                        if($(Get-VHD $using:dataVHDPath).Attached) {
                            Write-Host "$($using:dataVHDPath) is already attached."
                        }
                        else {
                            Write-Host "$($using:dataVHDPath) has not been attached."
                        }
                        return $(Get-VHD $using:dataVHDPath).Attached
                    }
                    GetScript = {
                        
                        return $using:dataVHDPath
                    }
                    DependsOn = "[xVMHyperV]$($NodeName)_$($VmName)_NewVM","[Script]$($NodeName)_$($VmName)_FormatDataDisk"         
                }
            }
        }     
    })
}