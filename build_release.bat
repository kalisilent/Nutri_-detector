@echo off
echo ============================================
echo  NutriScan Offline - Release APK Build
echo ============================================
echo.
echo [1/4] Cleaning...
call flutter clean
echo [2/4] Getting dependencies...
call flutter pub get
echo [3/4] Building release APK...
call flutter build apk --release --split-per-abi
echo [4/4] Done!
echo.
echo APKs at: build\app\outputs\flutter-apk\
echo   app-arm64-v8a-release.apk  (most phones)
echo   app-armeabi-v7a-release.apk (older phones)
echo.
pause
