Configuration xVMAutoCheckpoint {
    param (
        [string] $NodeName = 'localhost',

        [Parameter(Mandatory)]
        [string] $VmName,

        [Parameter(Mandatory)]
        [bool] $Enable
    )

    Script "$($NodeName)_$($VmName)_AutoCheckpoint" {
        SetScript = { 
            Set-VM -Name $using:VmName -AutomaticCheckpointsEnabled $using:Enable
        }
        TestScript = {
            $targetVm = $null
            $targetVm = Get-VM -Name $using:VmName
            
            if($targetVM -ne $null) {
                $autoCheckpoint = $targetVm.AutomaticCheckpointsEnabled
                if($autoCheckpoint -eq $using:Enable) {
                    Write-Host "VM $($using:VmName) Automatic Checkpoints is already Enabled=$($using:Enable)"
                    return $true
                }
                else {
                    return $false
                }
            }
            else {
                Write-Host "VM $($using:VmName) does not exist on $($using:NodeName)"
                return $true
            }
        }
        GetScript = {
            $targetVm = $null
            $targetVm = Get-VM -Name $using:VmName
            $autoCheckpoint = $false
            if($targetVM -ne $null) {
                $autoCheckpoint = $targetVm.AutomaticCheckpointsEnabled
            }

            return $autoCheckpoint
        }       
    } 
}