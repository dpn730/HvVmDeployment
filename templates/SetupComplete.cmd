rem This file must be copied to the C:\Windows\Setup\Scripts folder of the base image

start /wait msiexec.exe /q /i c:\Softlib\TrendMicro_DSA\Agent-Core-Windows-10.0.0-2649.x86_64.msi

start /wait wusa.exe C:\softlib\Windows_Updates\Win2016-Feb2018-Delta.msu /quiet /norestart