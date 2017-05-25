Configuration VMDeploy
{
    param
    (
        [string[]] $NodeName = 'localhost',

        [Parameter(Mandatory)]
        [string] $BaseVHDPath,
    
        [Parameter(Mandatory)]
        [string] $OutputBasePath,

        [Parameter(Mandatory)]
        [string] $VMName,

        [Parameter(Mandatory)]
        $StartupMemory,

        $MinimumMemory = $StartupMemory,
       
        $MaximumMemory = $StartupMemory,

        [Parameter(Mandatory)]
        [String] $SwitchName,

        [Parameter(Mandatory)]
        [Uint32] $ProcessorCount,

        [ValidateSet('Off','Paused','Running')]
        [String] $State = 'Off',

        [Switch] $WaitForIP
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xHyper-V

    Node $NodeName
    {        
        $newSystemVHDFolder = "$($OutputBasePath)\$($VMName)"
        $NewSystemVHDPath = "$($OutputBasePath)\$($VMName)\$($VMName)_C.vhdx"

        File "$($NodeName)_Folder" {
            Type = 'Directory'
            DestinationPath = $newSystemVHDFolder
            Ensure = 'Present'
        }

        # Copy VHD File - hard coded to Windows 2016 Core Eval for now
        File SystemDisk {
            SourcePath = "$($BaseVHDPath)\Windows2016_Golden.vhdx"
            DestinationPath = $NewSystemVHDPath      
            Type = "File"
            Ensure = "Present"
            DependsOn = "[File]$($NodeName)_Folder"
        }

        # create the generation 2 testVM out of the vhd.
        xVMHyperV NewVM
        {
            Ensure          = 'Present'
            Name            = $VMName
            VhdPath         = $NewSystemVHDPath
            SwitchName      = $SwitchName
            State           = $State
            Path            = $OutputBasePath
            Generation      = 2
            StartupMemory   = $StartupMemory
            MinimumMemory   = $MinimumMemory
            MaximumMemory   = $MaximumMemory
            ProcessorCount  = $ProcessorCount
            RestartIfNeeded = $true
            WaitForIP       = $WaitForIP 
            DependsOn       = "[File]SystemDisk"
        }
    }
}