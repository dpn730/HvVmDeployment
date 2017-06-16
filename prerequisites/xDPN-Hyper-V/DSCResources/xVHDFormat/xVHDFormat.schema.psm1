Configuration xVHDFormat {
    param (
        [string] $NodeName = 'localhost',

        [Parameter(Mandatory)]
        [string] $VmName,

        [Parameter(Mandatory)]
        [ValidateScript({$(Test-Path -Path "$($_)") -and ($_.ToLower().EndsWith('.vhd') `
            -or  $_.ToLower().EndsWith('.vhdx'))})]
        [string] $DataVHDPath,
        
        [ValidateLength(0,32)]
        [string] $VolumeLabel = "",

        [ValidateScript({$_ -match '[a-zA-Z]'})]
        [string] $DriveLetter = "Z",

        [ValidateSet("REFS","NTFS")]
        [string] $FileSystem = "NTFS"
    )

    Script "$($NodeName)_$($VmName)_FormatDataDisk"
    {
        SetScript = { 
            $disk = Get-VHD -Path $using:DataVHDPath | Mount-VHD -Passthru -NoDriveLetter
            $partition = $disk | Initialize-Disk -Passthru | New-Partition -UseMaximumSize
            $partition | Format-Volume -FileSystem $using:FileSystem -Confirm:$false -NewFileSystemLabel `
                "$($using:VolumeLabel)" -Force

            $partition[0] | Set-Partition -NewDriveLetter $using:DriveLetter
            Dismount-VHD -Path $using:DataVHDPath -Confirm:$false
        }
        TestScript = {
            $found = $false
            if(!$(Get-VHD $using:DataVHDPath).Attached) {                                                        
                Mount-VHD -Path $using:DataVHDPath -Confirm:$false -NoDriveLetter
                $(Get-Volume).foreach({
                    if($_.FileSystemLabel -eq "$($using:VolumeLabel)") {
                        Write-Host "$($using:DataVHDPath) has already been initialized."
                        $found = $true
                    }
                })
                Dismount-VHD -Path $using:DataVHDPath -Confirm:$false
            
                if(!$found) {
                    Write-Host "$($using:DataVHDPath) has not been initialized."                                    
                }                                
            }
            else {
                Write-Host "$($using:DataVHDPath) has already been attached and $($VmName) is running, unable to mount VHD."
                $found = $true
            }

            return $found
        }
        GetScript = {
            return $(Get-VHD $using:DataVHDPath).Path
        }      
    }
}