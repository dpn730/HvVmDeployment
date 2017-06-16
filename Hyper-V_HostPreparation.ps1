Configuration Hyper-V_HostPreparation
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $AllNodes.NodeName 
    {
        $NodeName = $Node.NodeName
        
        WindowsFeature "$($NodeName)_Hyper-V" {
            Ensure = 'Present'
            Name   = 'Hyper-V'
        }
        
        WindowsFeature "$($NodeName)_Hyper-V-Powershell" {
            Ensure = 'Present'
            Name = 'Hyper-V-Powershell'
            DependsOn = "[WindowsFeature]$($NodeName)_Hyper-V"
        }

        File "$($NodeName)_xHyper-V_Module" {
            Ensure = 'Present'
            DestinationPath = "$($env:ProgramFiles)\WindowsPowershell\Modules\xHyper-V"
            SourcePath = "$($PSScriptRoot)\prerequisites\xHyper-V"
            Recurse = $true
        }

        File "$($NodeName)_xDPN-Hyper-V_Module" {
            Ensure = 'Present'
            DestinationPath = "$($env:ProgramFiles)\WindowsPowershell\Modules\xDPN-Hyper-V"
            SourcePath = "$($PSScriptRoot)\prerequisites\xDPN-Hyper-V"
            Recurse = $true
        }
    }
}