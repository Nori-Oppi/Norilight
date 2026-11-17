@echo off
rem Norilight: simple local build (x64). Compiles and deploys a runnable folder.
rem Usage: scripts\build-norilight.bat [release^|debug]   (default: release)
rem Needs: Qt 6 MSVC x64 (QT_DIR, default C:\Qt\6.11.3\msvc2022_64), Visual Studio C++ tools,
rem        and prebuilt deps from setup-deps.ps1.
setlocal enableDelayedExpansion

set BUILD_CONFIG=%1
if "%BUILD_CONFIG%"=="" set BUILD_CONFIG=release
if not defined QT_DIR set QT_DIR=C:\Qt\6.11.3\msvc2022_64

set SOURCE_ROOT=%~dp0..
set BUILD_FOLDER=%SOURCE_ROOT%\build\build-x64-%BUILD_CONFIG%
set DEPLOY_FOLDER=%SOURCE_ROOT%\build\Norilight-x64-%BUILD_CONFIG%

if not exist "%QT_DIR%\bin\qmake.exe" (
    echo Qt not found at %QT_DIR%. Set QT_DIR.
    exit /b 1
)
if not exist "%SOURCE_ROOT%\libs\windows\lib\x64" (
    echo Prebuilt deps missing. Run setup-deps.ps1 first.
    exit /b 1
)

set PATH=%QT_DIR%\bin;%PATH%

where /q cl.exe
if !ERRORLEVEL! NEQ 0 (
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    for /f "usebackq delims=" %%i in (`call "!VSWHERE!" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_PATH=%%i"
    call "!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul
)
where /q cl.exe || (echo MSVC compiler not found & exit /b 1)

rem Compile several files at once inside each cl.exe call. This is needed with
rem jom too: it runs separate build steps in parallel, but each batch of
rem sources still goes to a single cl.exe call.
set CL=/MP

rem Prefer jom, which is parallel where nmake is serial
where /q jom.exe
if !ERRORLEVEL! EQU 0 (
    set MAKE_CMD=jom.exe
) else (
    set MAKE_CMD=nmake.exe /nologo
)

if not exist "%BUILD_FOLDER%" mkdir "%BUILD_FOLDER%"
pushd "%BUILD_FOLDER%"
echo === Configuring
rem USE_SCCACHE=1 routes the compiler through sccache (which must be on PATH).
rem no_batch makes every source file its own compiler call, the only kind sccache can reuse.
set QMAKE_EXTRA_ARGS=
if "%USE_SCCACHE%"=="1" set QMAKE_EXTRA_ARGS=CONFIG+=ccache CONFIG+=no_batch QMAKE_CACHE_LAUNCHER_PREFIX=sccache
qmake.exe "%SOURCE_ROOT%\moonlight-qt.pro" %QMAKE_EXTRA_ARGS% || goto Error
echo === Compiling (%BUILD_CONFIG%)
!MAKE_CMD! %BUILD_CONFIG% || goto Error
popd

echo === Deploying to %DEPLOY_FOLDER%
if exist "%DEPLOY_FOLDER%" rmdir /s /q "%DEPLOY_FOLDER%"
mkdir "%DEPLOY_FOLDER%"
copy /y "%BUILD_FOLDER%\app\%BUILD_CONFIG%\Norilight.exe" "%DEPLOY_FOLDER%" >nul || goto Error
copy /y "%SOURCE_ROOT%\libs\windows\lib\x64\*.dll" "%DEPLOY_FOLDER%" >nul || goto Error
copy /y "%BUILD_FOLDER%\AntiHooking\%BUILD_CONFIG%\AntiHooking.dll" "%DEPLOY_FOLDER%" >nul || goto Error
copy /y "%SOURCE_ROOT%\app\SDL_GameControllerDB\gamecontrollerdb.txt" "%DEPLOY_FOLDER%" >nul || goto Error

windeployqt.exe --dir "%DEPLOY_FOLDER%" --%BUILD_CONFIG% --qmldir "%SOURCE_ROOT%\app\gui" ^
    --no-opengl-sw --no-sql --skip-plugin-types qmltooling,generic --no-ffmpeg --force-openssl ^
    "%DEPLOY_FOLDER%\Norilight.exe" || goto Error

echo === Done: %DEPLOY_FOLDER%\Norilight.exe
exit /b 0

:Error
popd
echo === Build failed
exit /b 1
