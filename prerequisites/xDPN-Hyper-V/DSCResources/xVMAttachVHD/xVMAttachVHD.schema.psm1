Configuration xVMAttachVHD {
    param (
        [string] $NodeName = 'localhost',

        [Parameter(Mandatory)]
        [string] $VmName,

        [Parameter(Mandatory)]
        [ValidateScript({$(Test-Path -Path $_) -and ($_.ToLower().EndsWith('.vhd') `
            -or  $_.ToLower().EndsWith('.vhdx'))})]
        [string] $DataVhdPath
    )

    $VhdName = $(Split-Path -Path $DataVhdPath -Leaf)
    $VhdName = $VhdName.ToLower().Replace(".vhdx","").Replace(".vhd","").ToUpper()

    Script "$($NodeName)_$($VmName)_AttachDataDisk"
    {
        SetScript = { 
            Add-VMHardDiskDrive -VMName $using:VmName -Path $using:DataVhdPath
        }
        TestScript = {
            $found = $false
            foreach($disk in $(Get-VMHardDiskDrive -VMName $using:VmName)){
                if($disk.Path -eq $using:DataVhdPath) {
                    $found = $true
                }
            }

            if($found) {
                Write-Host "$($using:DataVhdPath) is already attached."
            }
            else {
                Write-Host "$($using:DataVhdPath) has not been attached."
            }
            return $found
        }
        GetScript = {
            
            return $using:DataVhdPath
        }
    }
}