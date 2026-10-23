# Script tu dong build APK va push Git tren o C cho HocZiTa
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  HOCZITA: BAT DAU BUILD APK VA PUSH GIT (HOAN TOAN O C)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

Set-Location "C:\Personal\HocZiTa"

Write-Host "[1/3] Dang build file APK Release..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[LOI] Build APK that bai!" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat..."
    exit $LASTEXITCODE
}

Write-Host "`n[THANH CONG] File APK Release da duoc build tai:" -ForegroundColor Green
Write-Host "C:\Personal\HocZiTa\build\app\outputs\flutter-apk\app-release.apk`n" -ForegroundColor Green

Write-Host "[2/3] Dang commit code len Git..." -ForegroundColor Yellow
git add .
git commit -m "feat(game): fix riverpod unmount error and update math english bubbles game"

Write-Host "`n[3/3] Dang push len GitHub (origin/main)..." -ForegroundColor Yellow
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "[LOI] Git push that bai!" -ForegroundColor Red
    Read-Host "Nhan Enter de thoat..."
    exit $LASTEXITCODE
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "  HOAN TAT 100%: DA CAP NHAT APK VA PUSH LEN GIT XONG!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Read-Host "Nhan Enter de hoan tat..."
