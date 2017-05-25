Function Convert-RvNetIpAddressToInt64 
{ 
    <# 
    .DESCRIPTION 
        Developer 
            Developer: Rudolf Vesely, http://rudolfvesely.com/ 
            Copyright (c) Rudolf Vesely. All rights reserved 
            License: Free for private use only 
    #> 
 
    Param 
    ( 
        [string] 
        $IpAddress 
    ) 
 
    $ipAddressParts = $IpAddress.Split('.') # IP to it's octets 
 
    # Return 
    [int64]([int64]$ipAddressParts[0] * 16777216 + 
            [int64]$ipAddressParts[1] * 65536 + 
            [int64]$ipAddressParts[2] * 256 + 
            [int64]$ipAddressParts[3]) 
} 
 
Function Convert-RvNetSubnetMaskClassesToCidr 
{ 
    <# 
    .DESCRIPTION 
        Developer 
            Developer: Rudolf Vesely, http://rudolfvesely.com/ 
            Copyright (c) Rudolf Vesely. All rights reserved 
            License: Free for private use only 
    #> 
 
    Param 
    ( 
        [string] 
        $SubnetMask 
    ) 
 
    [int64]$subnetMaskInt64 = Convert-RvNetIpAddressToInt64 -IpAddress $SubnetMask 
 
    $subnetMaskCidr32Int = 2147483648 # 0x80000000 - Same as Convert-RvNetIpAddressToInt64 -IpAddress '255.255.255.255' 
 
    $subnetMaskCidr = 0 
    for ($i = 0; $i -lt 32; $i++) 
    { 
        if (!($subnetMaskInt64 -band $subnetMaskCidr32Int) -eq $subnetMaskCidr32Int) { break } # Bitwise and operator - Same as "&" in C# 
 
        $subnetMaskCidr++ 
        $subnetMaskCidr32Int = $subnetMaskCidr32Int -shr 1 # Bit shift to the right - Same as ">>" in C# 
    } 
 
    # Return 
    $subnetMaskCidr 
}