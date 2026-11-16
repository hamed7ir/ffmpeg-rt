@echo off
rem kodi-rt: plain against PGO + ThinLTO, the same shared FFmpeg 9.0.2 (same source, components and compiler),
rem on the same clips. Per clip, the two builds take turns (plain, pgo, plain, pgo, plain, pgo) so heat hits both alike:
rem   t1    10 s decoded on one thread, frames only (like TelegArm's "one thread, no conversion")
rem   tbgra 10 s decoded on all threads and turned into BGRA (like TelegArm's "threads + BGRA")
rem   audio the whole audio track decoded (AAC, MP3, Opus)
rem ffmpeg's -benchmark times go to results\log.txt; the best of three per build is worked out later.
setlocal
set "HERE=%~dp0"
for %%b in (plain pgo) do if not exist "%HERE%ffmpeg-%%b\ffmpeg.exe" (echo ffmpeg-%%b\ffmpeg.exe is missing.& pause & exit /b 1)
set "OUT="
if not exist "%HERE%results" set "OUT=%HERE%results"
for /l %%i in (2,1,99) do if not defined OUT if not exist "%HERE%results-%%i" set "OUT=%HERE%results-%%i"
if not defined OUT (echo There is no free name for a results folder. Move the old results folders away first.& pause & exit /b 1)
mkdir "%OUT%"
set "LOG=%OUT%\log.txt"
echo kodi-rt ffbench run 1, %date% %time% > "%LOG%"
ver >> "%LOG%"
for %%f in ("%HERE%clips\*") do if /i not "%%~nxf"=="README.txt" call :clip "%%f"
echo. >> "%LOG%"
echo end %date% %time% >> "%LOG%"
echo.
echo Done. Zip this folder and send it:
echo %OUT%
pause
exit /b 0

:clip
echo %time% %~nx1
for %%m in (t1 tbgra audio) do for /l %%i in (1,1,3) do (
  call :run plain %%m "%~1"
  call :run pgo %%m "%~1"
)
goto :eof

:run
echo === %~nx3 %2 %1 >> "%LOG%"
if "%2"=="t1"    "%HERE%ffmpeg-%1\ffmpeg.exe" -hide_banner -nostdin -benchmark -threads 1 -t 10 -i "%~3" -map 0:v? -f null - >> "%LOG%" 2>&1
if "%2"=="tbgra" "%HERE%ffmpeg-%1\ffmpeg.exe" -hide_banner -nostdin -benchmark -t 10 -i "%~3" -map 0:v? -pix_fmt bgra -f null - >> "%LOG%" 2>&1
if "%2"=="audio" "%HERE%ffmpeg-%1\ffmpeg.exe" -hide_banner -nostdin -benchmark -i "%~3" -map 0:a? -vn -f null - >> "%LOG%" 2>&1
goto :eof
