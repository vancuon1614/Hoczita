@echo off
chcp 65001 >nul
title HocZiTa - Build APK va Push Git
echo ========================================================
echo   HOCZITA: BAT DAU BUILD APK VA PUSH GIT (HOAN TOAN O C)
echo ========================================================
echo.

cd /d "C:\Personal\HocZiTa"

echo [1/3] Dang build file APK Release...
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ----------------------------------------------------
    echo [LOI] Build APK that bai! Vui long xem chi tiet loi tren.
    echo ----------------------------------------------------
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [THANH CONG] File APK Release da duoc build tai:
echo C:\Personal\HocZiTa\build\app\outputs\flutter-apk\app-release.apk
echo.

echo [2/3] Dang them cac thay doi va commit Git...
git add .
git commit -m "feat(game): fix riverpod unmount error and update math english bubbles game"

echo.
echo [3/3] Dang push code len GitHub (origin/main)...
git push origin main
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ----------------------------------------------------
    echo [LOI] Git push that bai! Kiem tra ket noi hoac xac thuc.
    echo ----------------------------------------------------
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo ========================================================
echo   HOAN TAT 100%: DA CAP NHAT APK VA PUSH LEN GIT XONG!
echo ========================================================
echo.
pause
