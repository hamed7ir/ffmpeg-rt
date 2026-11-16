@echo off
rem kodi-rt: PGO training run for the shared FFmpeg 9.0.2 (TelegArm, the ffmpeg-rt release). An INSTRUMENTED
rem ffmpeg.exe decodes every file in clips\ four ways, as TelegArm uses FFmpeg: as it is (all threads), on one thread,
rem video turned into BGRA (swscale), audio turned into 48 kHz stereo s16 at 1.25x speed (swresample, avfilter).
rem The DLLs count what runs: one .profraw file per DLL in results\prof, the output in results\log.txt.
rem Each pass decodes 40 seconds of a file (shorter files loop); the counting build is slower than a normal one.
setlocal
set "HERE=%~dp0"
set "FF=%HERE%ffmpeg\ffmpeg.exe"
if not exist "%FF%" (echo ffmpeg\ffmpeg.exe is missing.& pause & exit /b 1)
set "N=0"
for %%f in ("%HERE%clips\*") do if /i not "%%~nxf"=="README.txt" set /a N+=1
if "%N%"=="0" (echo Put some video and audio files into the clips folder first, see README.txt.& pause & exit /b 1)
set "OUT="
if not exist "%HERE%results" set "OUT=%HERE%results"
for /l %%i in (2,1,99) do if not defined OUT if not exist "%HERE%results-%%i" set "OUT=%HERE%results-%%i"
if not defined OUT (echo There is no free name for a results folder. Move the old results folders away first.& pause & exit /b 1)
mkdir "%OUT%\prof"
set "LLVM_PROFILE_FILE=%OUT%\prof\ff-%%m.profraw"
set "LOG=%OUT%\log.txt"
echo kodi-rt ffpgo run 1: %N% files, %date% %time% > "%LOG%"
ver >> "%LOG%"
"%FF%" -hide_banner -version >> "%LOG%" 2>&1
for %%f in ("%HERE%clips\*") do if /i not "%%~nxf"=="README.txt" call :one "%%f"
echo. >> "%LOG%"
echo end %date% %time% >> "%LOG%"
dir "%OUT%\prof" >> "%LOG%"
echo.
echo Done. Zip this folder and send it:
echo %OUT%
pause
exit /b 0

:one
echo %time% %~nx1
echo. >> "%LOG%"
echo === %~nx1 >> "%LOG%"
"%FF%" -hide_banner -nostdin -benchmark -stream_loop -1 -t 40 -i "%~1" -f null - >> "%LOG%" 2>&1
"%FF%" -hide_banner -nostdin -benchmark -threads 1 -stream_loop -1 -t 40 -i "%~1" -f null - >> "%LOG%" 2>&1
"%FF%" -hide_banner -nostdin -benchmark -stream_loop -1 -t 40 -i "%~1" -map 0:v? -pix_fmt bgra -f null - >> "%LOG%" 2>&1
"%FF%" -hide_banner -nostdin -benchmark -stream_loop -1 -t 40 -i "%~1" -map 0:a? -af "aresample=48000,aformat=sample_fmts=s16:channel_layouts=stereo,atempo=1.25" -f null - >> "%LOG%" 2>&1
goto :eof
