@echo off
:: 隱藏視窗執行你的主程式
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "generate.ps1"

:: 如果執行失敗（ERRORLEVEL 不為 0），就用 PowerShell 彈出紅色警告並暫停
if %ERRORLEVEL% NEQ 0 (
    powershell.exe -Command "Write-Host '`n❌ 糟糕！執行過程中發生了錯誤。' -ForegroundColor Red; Write-Host '💡 提示：請檢查 items.csv 是否被 Excel 鎖定，或是路徑是否正確。`n' -ForegroundColor Yellow; Read-Host '請按 Enter 鍵結束'"
)