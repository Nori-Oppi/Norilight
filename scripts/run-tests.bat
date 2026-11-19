@echo off
rem Norilight: builds and runs the Windows regression tests (tests\profiles, tests\autotune,
rem tests\optimise, tests\livesettings, tests\input).
rem Run after scripts\build-norilight.bat release, which deploys the DLLs the tests load.
rem Needs: Qt 6 MSVC x64 (QT_DIR, default C:\Qt\6.11.3\msvc2022_64) and Visual Studio C++ tools.
setlocal enableDelayedExpansion

if not defined QT_DIR set QT_DIR=C:\Qt\6.11.3\msvc2022_64
set SOURCE_ROOT=%~dp0..
set DEPLOY_FOLDER=%SOURCE_ROOT%\build\Norilight-x64-release
set TEST_FOLDER=%SOURCE_ROOT%\build\profiles-tests

if not exist "%QT_DIR%\bin\qmake.exe" (
    echo Qt not found at %QT_DIR%. Set QT_DIR.
    exit /b 1
)
if not exist "%DEPLOY_FOLDER%\Norilight.exe" (
    echo Build Norilight first: scripts\build-norilight.bat release
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

where /q jom.exe
if !ERRORLEVEL! EQU 0 (
    set MAKE_CMD=jom.exe
) else (
    set MAKE_CMD=nmake.exe /nologo
)

echo === Building profile tests
if not exist "%TEST_FOLDER%" mkdir "%TEST_FOLDER%"
pushd "%TEST_FOLDER%"
qmake.exe "%SOURCE_ROOT%\tests\profiles\profiles.pro" CONFIG+=release || goto Error
!MAKE_CMD! release || goto Error
popd

echo === Building launch tuning test
if not exist "%SOURCE_ROOT%\build\autotune-tests" mkdir "%SOURCE_ROOT%\build\autotune-tests"
pushd "%SOURCE_ROOT%\build\autotune-tests"
qmake.exe "%SOURCE_ROOT%\tests\autotune\autotune.pro" CONFIG+=release || goto Error
!MAKE_CMD! release || goto Error
popd

echo === Building optimise test
if not exist "%SOURCE_ROOT%\build\optimise-tests" mkdir "%SOURCE_ROOT%\build\optimise-tests"
pushd "%SOURCE_ROOT%\build\optimise-tests"
qmake.exe "%SOURCE_ROOT%\tests\optimise\optimise.pro" CONFIG+=release || goto Error
!MAKE_CMD! release || goto Error
popd

echo === Building stream settings menu test
if not exist "%SOURCE_ROOT%\build\livesettings-tests" mkdir "%SOURCE_ROOT%\build\livesettings-tests"
pushd "%SOURCE_ROOT%\build\livesettings-tests"
qmake.exe "%SOURCE_ROOT%\tests\livesettings\livesettings.pro" CONFIG+=release || goto Error
!MAKE_CMD! release || goto Error
popd

echo === Building screenshot shortcut test
cl /nologo /EHsc /std:c++17 /MD /I"%SOURCE_ROOT%\app" /I"%SOURCE_ROOT%\libs\windows\include\x64\SDL2" ^
    "%SOURCE_ROOT%\tests\input\ScreenshotShortcutTest.cpp" /Fo"%SOURCE_ROOT%\build\ScreenshotShortcutTest.obj" ^
    /Fe"%DEPLOY_FOLDER%\ScreenshotShortcutTest.exe" ^
    /link "%SOURCE_ROOT%\libs\windows\lib\x64\SDL2.lib" user32.lib || exit /b 1

echo === Running profile tests
powershell -NoProfile -ExecutionPolicy Bypass -File "%SOURCE_ROOT%\tests\profiles\run.ps1" ^
    -QtDir "%QT_DIR%" -Binary "%TEST_FOLDER%\release\ProfilesTest.exe" || exit /b 1

echo === Running launch tuning test
"%SOURCE_ROOT%\build\autotune-tests\release\AutoTuneTest.exe" || exit /b 1

echo === Running optimise test
"%SOURCE_ROOT%\build\optimise-tests\release\OptimisePickTest.exe" || exit /b 1

echo === Running stream settings menu test
"%SOURCE_ROOT%\build\livesettings-tests\release\LiveSettingsTest.exe" || exit /b 1

echo === Running screenshot shortcut test
"%DEPLOY_FOLDER%\ScreenshotShortcutTest.exe" || exit /b 1
rem Keep the test binary out of the deployed folder that gets packaged
del "%DEPLOY_FOLDER%\ScreenshotShortcutTest.exe"

echo === All tests passed
exit /b 0

:Error
popd
echo === Test build failed
exit /b 1
