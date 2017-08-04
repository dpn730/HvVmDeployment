.'.\lib\Convert-RvNetIpAddressToInt64.ps1'
.'.\lib\Get-UnattendXmlFilename.ps1'

Configuration Hyper-V_Configuration
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xHyper-V
    Import-DscResource -Module xDPN-Hyper-V

    $gigabyte = 1073741824

    Node $AllNodes.NodeName 
    {
        $NodeName = $Node.NodeName
        $VmData = $Node.VmData         
        $vSwitchData = $Node.vSwitchData

        # Configure vSwitches if provided
        foreach($vSwitch in $vSwitchData) {
            if($vSwitch.vSwitchType -eq 'External') {
                xVmSwitch "$($NodeName)_$($vSwitch.vSwitchName)_vSwitch" {
                    Ensure = 'Present'
                    Name = $vSwitch.vSwitchName
                    Type = $vSwitch.vSwitchType
                    NetAdapterName = $vSwitch.NetAdapterName
                    AllowManagementOS = [bool] $vSwitch.AllowManagementOS
                 }
            }          
        }

        # Configure VMs if provided
        foreach($Vm in $VmData) {
            Write-Host $Vm
            $VmName = $Vm.hostname
            $DestPath = $Vm.destPath
            $OsFamily = $Vm.osFamily
            $OsVhd = $Vm.osVhd
            $OsVersion = $Vm.osVersion                
            $OsEdition = $Vm.osEdition
            $DomainJoin = [System.Convert]::ToBoolean($Vm.domainJoin)
            $IpConfig = $Vm.ipConfig
            $Memory = $Vm.memory
            $CPU = $Vm.vCpu
            $DataDisks = $Vm.dataDisks
            $VmDependsOn = @()
            $VmState = 'Off'
            $VmExists = $false
            $VmGeneration = $Vm.generation

            # Ip Configuration Variables
            $VmSwitchName = $IpConfig.vSwitchName
            $VlanId = $IpConfig.vlanID
            # unattend.xml Variables
            $VmIp = $IpConfig.ipAddress
            $VmSubnetMask = Convert-RvNetSubnetMaskClassesToCidr $IpConfig.subnetMask
            $Gateway = $IpConfig.defaultGateway
            $DnsIps = @("","","","") 
            
            $dnsCount = 0
            foreach($dnsIP in $Vm.dnsIP) {
                $DnsIps[$dnsCount] = $dnsIP.ip
                $dnsCount++
            }

            $newSystemVhdFolder = "$($DestPath)\$($VmName)"
            $osVhdPath = "$($newSystemVhdFolder)\$($VMName)_OS.vhdx"                

            # Create VHD Folder
            File "$($NodeName)_$($VmName)_Folder" {
                Type = 'Directory'
                DestinationPath = $newSystemVhdFolder
                Ensure = 'Present'
            }

            # Create OS VHD from image
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
                $sourceUnattendXmlFilename = Get-UnattendXmlFilename -OsVersion $OsVersion -OsEdition $OsEdition -DomainJoin $DomainJoin
                $sourceUnattendXmlContent = Get-Content "$($PSScriptRoot)\templates\$($sourceUnattendXmlFilename)"
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

            # Create the Vm
            xVMHyperV "$($NodeName)_$($VmName)_NewVM" {
                Ensure          = 'Present'
                Name            = $VmName
                VhdPath         = $osVhdPath
                SwitchName      = $VmSwitchName
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
                $dataVolumeLabel = "$($VmName)_$($disk.volumeLabel)"
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
                    xVHDFormat "$($NodeName)_$($VmName)_FormatDataDisk_$($dataVhdDriveLetter)" 
                    {
                        NodeName = $NodeName
                        VmName = $VmName
                        DataVhdPath = $dataVhdPath
                        VolumeLabel = $dataVolumeLabel
                        DriveLetter = $dataVhdDriveLetter
                        DependsOn = "[xVHD]$($NodeName)_$($VmName)_DataDisk_$($dataVhdDriveLetter)" 
                    }
                    
                    $attachDiskDependency += "[xVHDFormat]$($NodeName)_$($VmName)_FormatDataDisk_$($dataVhdDriveLetter)"                   
                }

                xVMAttachVHD "$($NodeName)_$($VmName)_AttachDataDisk_$($dataVhdDriveLetter)" 
                {
                    NodeName = $NodeName
                    VmName = $VmName
                    DataVhdPath = $dataVhdPath
                    DependsOn = $attachDiskDependency
                }
            }
            
            # Configure Vlan ID if provided
            if(![string]::IsNullOrEmpty($VlanId)) {
                xVMSwitchVlanId "$($NodeName)_$($VmName)_VlanID" 
                {
                    NodeName = $NodeName
                    VmName = $VmName
                    VmSwitchName = $VmSwitchName
                    VlanId = $VlanId
                    DependsOn = "[xVMHyperV]$($NodeName)_$($VmName)_NewVM"
                } 
            }
        }     
    }
}