$testBasePath = 'c:\Users\David Paul Ngo\Downloads'
$testOutputPath = 'c:\Users\David Paul Ngo\Virtual Machines'

.'.\VMDeploy.ps1'
VMDeploy -BaseVHDPath $testBasePath -OutputBasePath $testOutputPath -VMName 'DPN-TestVM' `
    -StartupMemory 2GB -SwitchName 'VM_External_VNIC' -ProcessorCount '4' -State 'Running'

Start-DscConfiguration -Wait -Force -Verbose -ComputerName localhost -Path $PSScriptRoot\VMDeploy