@echo OFF
setlocal

REM Defined script variables
set C99WRAPDL=https://github.com/libav/c99-to-c89/releases/download
set C99WRAPVERSION=1.0.3
set VSWHEREDL=https://github.com/Microsoft/vswhere/releases/download
set VSWHEREVERSION=2.6.7

REM Store current directory and ensure working directory is the location of current .bat
set CALLDIR=%CD%
set SCRIPTDIR=%~dp0

REM Check what architecture we are installing on
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo Detected 64 bit system...
    set SYSARCH=64
) else if "%PROCESSOR_ARCHITECTURE%"=="x86" (
    if "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
        echo Detected 64 bit system running 32 bit shell...
        set SYSARCH=64
    ) else (
        echo Detected 32 bit system...
        set SYSARCH=32
    )
) else (
    echo Error: Could not detect current platform architecture!"
    goto Terminate
)

REM Initialise error check value
set ERROR=0
REM Check if being called from another instance
if not "%~1"=="" (
    set "MSVC_VER=%~1"
    set "VSINSTANCEDIR=%~2"
    goto MSVCCALL
)

REM Check if already running in an environment with VS setup
if defined VCINSTALLDIR (
    if defined VisualStudioVersion (
        echo Existing Visual Studio environment detected...
        if "%VisualStudioVersion%"=="14.0" (
            set MSVC_VER=14
            goto MSVCVarsDone
        ) else if "%VisualStudioVersion%"=="12.0" (
            set MSVC_VER=12
            goto MSVCVarsDone
        ) else if "%VisualStudioVersion%"=="11.0" (
            set MSVC_VER=11
            goto MSVCVarsDone
        ) else (
            echo Unknown Visual Studio environment detected '%VisualStudioVersion%', Creating a new one...
        )
    )
)

:MSVCRegDetection
if "%SYSARCH%"=="32" (
    set MSVCVARSDIR=
    set WOWNODE=
) else if "%SYSARCH%"=="64" (
    set MSVCVARSDIR=\amd64
    set WOWNODE=\WOW6432Node
) else (
    goto Terminate
)
REM First check for a environment variable to help locate the VS installation
if defined VS140COMNTOOLS (
    if exist "%VS140COMNTOOLS%..\..\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat" (
        echo Visual Studio 2015 environment detected...
        call "%~0" "14" "%VS140COMNTOOLS%..\..\"
        if not ERRORLEVEL 1 (
            set MSVC14=1
            set MSVCFOUND=1
        )
    )
)
if defined VS120COMNTOOLS (
    if exist "%VS120COMNTOOLS%..\..\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat" (
        echo Visual Studio 2013 environment detected...
        call "%~0" "12" "%VS120COMNTOOLS%..\..\"
        if not ERRORLEVEL 1 (
            set MSVC12=1
            set MSVCFOUND=1
        )
    )
)

if defined VS110COMNTOOLS (
    if exist "%VS110COMNTOOLS%..\..\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat" (
        echo Visual Studio 2012 environment detected...
        call "%~0" "11" "%VS110COMNTOOLS%..\..\"
        if not ERRORLEVEL 1 (
            set MSVC11=1
            set MSVCFOUND=1
        )
    )
)

if not defined MSVCFOUND (
    echo Error: Could not find valid Visual Studio installation!
    goto Terminate
)
goto Exit

:MSVCCALL
if "%SYSARCH%"=="32" (
    set MSVCVARSDIR=
) else if "%SYSARCH%"=="64" (
    set MSVCVARSDIR=\amd64
) else (
    goto Terminate
)
REM Call the required vcvars file in order to setup up build locations
if "%MSVC_VER%"=="15" (
    set "VCVARS=%VSINSTANCEDIR%\VC\Auxiliary\Build\vcvars%SYSARCH%.bat"
) else if "%MSVC_VER%"=="14" (
    set "VCVARS=%VSINSTANCEDIR%\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat"
) else if "%MSVC_VER%"=="12" (
    set "VCVARS=%VSINSTANCEDIR%\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat"
) else if "%MSVC_VER%"=="11" (
    set "VCVARS=%VSINSTANCEDIR%\VC\bin%MSVCVARSDIR%\vcvars%SYSARCH%.bat"
) else (
    echo Error: Invalid MSVC version!
    goto Terminate
)
if exist "%VCVARS%" (
    call "%VCVARS%" >nul 2>&1
) else (
    echo Error: Invalid VS install location detected!
    goto Terminate
)

:MSVCVarsDone
if "%MSVC_VER%"=="15" (
    set "VCTargetsPath=%VSINSTANCEDIR%\Common7\IDE\VC\VCTargets\BuildCustomizations"
) else (
    set "VCTargetsPath=%ProgramFiles(x86)%\MSBuild\Microsoft.Cpp\v4.0\V%MSVC_VER%0\BuildCustomizations"
)

REM copy the BuildCustomizations to VCTargets folder
echo Installing build customisations...
copy /B /Y "%SCRIPTDIR%\c99wrap.*" "%VCTargetsPath%\" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to copy build customisations!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    goto Terminate
)

REM Download the latest c99wrap binary for windows
if exist "%SCRIPTDIR%\c99wrap_%C99WRAPVERSION%.zip" (
    echo Using existing C99WRAP binary...
    goto InstallC99WRAP
)
set C99WRAPDOWNLOAD=%C99WRAPDL%/release-%C99WRAPVERSION%/c99-to-c89-%C99WRAPVERSION%.zip
echo Downloading required C99WRAP release binary...
powershell.exe -Command (New-Object Net.WebClient).DownloadFile('%C99WRAPDOWNLOAD%', '%SCRIPTDIR%\c99wrap_%C99WRAPVERSION%.zip') >nul 2>&1
if not exist "%SCRIPTDIR%\c99wrap_%C99WRAPVERSION%.zip" (
    echo Error: Failed to download required C99WRAP binary!
    echo    The following link could not be resolved "%C99WRAPDOWNLOAD%"
    goto Terminate
)

:InstallC99WRAP
echo VCINSTALLDIR=%VCINSTALLDIR%
echo VCTargetsPath=%VCTargetsPath%
powershell.exe -Command Add-Type -A 'System.IO.Compression.FileSystem'; [IO.Compression.ZipFile]::ExtractToDirectory('"%SCRIPTDIR%\c99wrap_%C99WRAPVERSION%.zip"', '"%SCRIPTDIR%\TempC99WRAPUnpack"') >nul 2>&1
if not exist "%SCRIPTDIR%\TempC99WRAPUnpack" (
    echo Error: Failed to unpack C99WRAP download!
    del /F /Q "%SCRIPTDIR%\c99wrap_.zip" >nul 2>&1
    goto Terminate
)

REM copy c99wrap executable to VC installation folder
echo Installing required C99WRAP release binary...
copy /B /Y "%SCRIPTDIR%\TempC99WRAPUnpack\c99conv.exe" "%VCINSTALLDIR%" >nul 2>&1
copy /B /Y "%SCRIPTDIR%\TempC99WRAPUnpack\c99wrap.exe" "%VCINSTALLDIR%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to install C99WRAP binary!
    echo    Ensure that this script is run in a shell with the necessary write privileges
    rd /S /Q "%SCRIPTDIR%\TempC99WRAPUnpack" >nul 2>&1
    goto Terminate
)
rd /S /Q "%SCRIPTDIR%\TempC99WRAPUnpack" >nul 2>&1
echo Finished Successfully
goto Exit

:Terminate
set ERROR=1

:Exit
cd %CALLDIR%
endlocal & exit /b %ERROR%
