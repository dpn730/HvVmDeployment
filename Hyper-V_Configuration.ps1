Configuration Hyper-V_Configuration
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xHyper-V

    $gigabyte = 1073741824

    Node $AllNodes.NodeName 
    {
        $NodeName = $Node.NodeName
        $VmData = $Node.VmData
        
        WindowsFeature "$($NodeName)_Hyper-V" {
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
            $OsFamily = $Vm.osFamily
            $OsVhd = $Vm.osVhd
            $OsVersion = $Vm.osVersion                
            $IpConfig = $Vm.ipConfig
            $Memory = $Vm.memory
            $CPU = $Vm.vCpu
            $DataDisks = $Vm.dataDisks
            $VmDependsOn = @()
            $VmState = 'Off'
            $VmExists = $false
            $VmGeneration = $Vm.generation

            # Ip Configuration Variables
            $VmSwitch = $IpConfig.vSwitchName
            $VlanId = $IpConfig.vlanID
            # unattend.xml Variables
            $VmIp = $IpConfig.ipAddress
            $VmSubnetMask = Convert-RvNetSubnetMaskClassesToCidr $IpConfig.subnetMask
            $Gateway = $IpConfig.defaultGateway
            $DnsIp1 = $Vm.dnsIP[0].ip

            $newSystemVhdFolder = "$($DestPath)\$($VmName)"
            $osVhdPath = "$($newSystemVhdFolder)\$($VMName)_OS.vhdx"                

            File "$($NodeName)_$($VmName)_Folder" {
                Type = 'Directory'
                DestinationPath = $newSystemVhdFolder
                Ensure = 'Present'
            }

            File "$($NodeName)_$($VmName)_SystemDisk" {
                SourcePath = "$OsVhd"
                DestinationPath = $osVhdPath      
                Type = "File"
                Ensure = "Present"
                DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
            }
            $VmDependsOn += "[File]$($NodeName)_$($VmName)_SystemDisk" 

            # Check if VM exists already and set the state
            foreach($hostedVm in $(Get-VM -ComputerName $NodeName | Select-Object Name,State)) {
                if($hostedVm.Name -eq $VmName) {
                    $VmState = $hostedVm.State
                    $VmExists = $true
                }
            }

            # If VM has not been created, prepare unattend.xml file
            if($VmExists -eq $false -and $OsFamily -eq "windows") {
                # Generate content of the unattend.xml from the template
                $sourceUnattendXmlContent = Get-Content "$(Split-Path -parent $PSCommandPath)\templates\unattend_$($OsVersion).xml"
                $sourceUnattendXmlContent = $ExecutionContext.InvokeCommand.ExpandString($sourceUnattendXmlContent)
                $newUnattendXmlPath = "$($newSystemVhdFolder)\unattend.xml"
                
                File "$($NodeName)_$($VmName)_UnattendedFile" {
                    Ensure = "Present"
                    Type = "File"
                    DestinationPath = $newUnattendXmlPath
                    Contents = [string] $sourceUnattendXmlContent
                    DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
                } 
                
                xVhdFile "$($NodeName)_$($VmName)_CopyUnattendxml"
                {
                    VhdPath =  $osVhdPath
                    FileDirectory =  MSFT_xFileDirectory {
                                    SourcePath = $newUnattendXmlPath
                                    DestinationPath = "\Windows\Panther\unattend.xml"
                                }
                    DependsOn = "[File]$($NodeName)_$($VmName)_SystemDisk","[File]$($NodeName)_$($VmName)_UnattendedFile"
                }

                $VmDependsOn += "[xVhdFile]$($NodeName)_$($VmName)_CopyUnattendxml"
            }

            xVMHyperV "$($NodeName)_$($VmName)_NewVM" {
                Ensure          = 'Present'
                Name            = $VmName
                VhdPath         = $osVhdPath
                SwitchName      = $VmSwitch
                State           = $VmState
                Path            = $newSystemVhdFolder
                Generation      = $VmGeneration
                StartupMemory   = $([int] $Memory * $gigabyte)
                ProcessorCount  = $CPU
                RestartIfNeeded = $true
                WaitForIP       = $WaitForIP 
                DependsOn       = $VmDependsOn
            }

            # Create and attach each data disk
            foreach($disk in $DataDisks) {                
                $dataVhdPath = "$($newSystemVhdFolder)\$($VMName)_$($disk.volumeLabel).vhdx"
                $dataVhdSize = $disk.size
                $dataVhdDriveLetter = $disk.driveLetter
                $dataVolumeLabel = $disk.volumeLabel
                $attachDiskDependency = @("[xVMHyperV]$($NodeName)_$($VmName)_NewVM")

                xVHD "$($NodeName)_$($VmName)_DataDisk_$($dataVhdDriveLetter)"
                {
                    Ensure           = 'Present'
                    Name             = Split-Path $dataVhdPath -leaf
                    Path             = Split-Path $dataVhdPath
                    Generation       = 'vhdx'
                    MaximumSizeBytes = $([int] $dataVhdSize * $gigabyte)
                    DependsOn = "[File]$($NodeName)_$($VmName)_Folder"
                }
                $attachDiskDependency += "[xVHD]$($NodeName)_$($VmName)_DataDisk_$($dataVhdDriveLetter)"        
                
                if($OsFamily -eq "windows") {
                    Script "$($NodeName)_$($VmName)_FormatDataDisk_$($dataVhdDriveLetter)"
                    {
                        SetScript = { 
                            $disk = Get-VHD -Path $using:dataVhdPath | Mount-VHD -Passthru -NoDriveLetter
                            $partition = $disk | Initialize-Disk -Passthru | New-Partition -UseMaximumSize
                            $partition | Format-Volume -FileSystem NTFS -Confirm:$false -NewFileSystemLabel `
                                "$($using:VmName)_$($using:dataVolumeLabel)" -Force

                            $partition[0] | Set-Partition -NewDriveLetter $using:dataVhdDriveLetter
                            Dismount-VHD -Path $using:dataVhdPath -Confirm:$false
                        }
                        TestScript = {
                            $found = $false
                            if(!$(Get-VHD $using:dataVhdPath).Attached) {                                                        
                                Mount-VHD -Path $using:dataVhdPath -Confirm:$false -NoDriveLetter
                                $(Get-Volume).foreach({
                                    if($_.FileSystemLabel -eq "$($using:VmName)_DATA") {
                                        Write-Host "$($using:dataVhdPath) has already been initialized."
                                        $found = $true
                                    }
                                })
                                Dismount-VHD -Path $using:dataVhdPath -Confirm:$false
                            
                                if(!$found) {
                                    Write-Host "$($using:dataVhdPath) has not been initialized."                                    
                                }                                
                            }
                            else {
                                Write-Host "$($using:dataVhdPath) has already been attached and $($using:VmName) is running, unable to mount VHD."
                                $found = $true
                            }

                            return $found
                        }
                        GetScript = {
                            return $(Get-VHD $using:dataVhdPath).Path
                        }
                        DependsOn = "[xVHD]$($NodeName)_$($VmName)_DataDisk_$($dataVhdDriveLetter)"         
                    }
                    $attachDiskDependency += "[Script]$($NodeName)_$($VmName)_FormatDataDisk_$($dataVhdDriveLetter)"
                }

                Script "$($NodeName)_$($VmName)_AttachDataDisk_$($dataVhdDriveLetter)"
                {
                    SetScript = { 
                        Add-VMHardDiskDrive -VMName $using:VmName -Path $using:dataVhdPath
                    }
                    TestScript = {
                        $found = $false
                        foreach($disk in $(Get-VMHardDiskDrive -VMName $using:VmName)){
                            if($disk.Path -eq $using:dataVhdPath) {
                                $found = $true
                            }
                        }

                        if($found) {
                            Write-Host "$($using:dataVhdPath) is already attached."
                        }
                        else {
                            Write-Host "$($using:dataVhdPath) has not been attached."
                        }
                        return $found
                    }
                    GetScript = {
                        
                        return $using:dataVhdPath
                    }
                    DependsOn =  $attachDiskDependency        
                }
            }
    
            Script "$($NodeName)_$($VmName)_VlanID" {
                SetScript = { 
                    foreach($vNic in $(Get-VMNetworkAdapter -VMName $using:VmName)) {
                        if($vNic.SwitchName -eq $using:VmSwitch) {
                            $vNic | Set-VMNetworkAdapterVlan -Access -VlanId $using:VlanId
                        }
                    }
                }
                TestScript = {
                    $targetVnic = $null
                    foreach($vNic in $(Get-VMNetworkAdapter -VMName $using:VmName)) {
                        if($vNic.SwitchName -eq $using:VmSwitch) {
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
                }
                GetScript = {
                    $targetVnic = $null
                    foreach($vNic in $(Get-VMNetworkAdapter -VMName $using:VmName)) {
                        if($vNic.SwitchName -eq $using:VmSwitch) {
                            $targetVnic = $vNic
                        }
                    }
                    return $($targetVnic | Get-VMNetworkAdapterVlan).AccessVlanId
                }
                DependsOn = "[xVMHyperV]$($NodeName)_$($VmName)_NewVM"         
            }
        }     
    }
}