@echo off

type C:\hello.txt

echo.
echo [System Info]
ver
echo ARCH=%PROCESSOR_ARCHITECTURE%

echo.
echo [Container Info]
echo BASE_IMAGE=%BASE_IMAGE%
echo BASE_VERSION=%BASE_VERSION%
echo IMAGE_NAME=%IMAGE_NAME%
echo IMAGE_TAG=%IMAGE_TAG%

rem Isolation mode of Windows Container
for /f "tokens=3* skip=1" %%a in ('reg query "HKLM\HARDWARE\DESCRIPTION\System" /v SystemBiosVersion 2^>nul') do (
    set "BIOS_VERSION=%%a %%b"
)
if "%BIOS_VERSION%" neq "%BIOS_VERSION:Hyper-V=%" (
    set ISOLATION=Hyper-V
) else (
    set ISOLATION=Process
)
echo ISOLATION=%ISOLATION%
