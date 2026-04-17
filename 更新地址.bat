@echo off
chcp 65001 > nul
echo ===================================================
echo 🚗 正在為你的發射引擎更新最新的雲端地址...
echo ===================================================
git remote set-url origin https://github.com/select-store/sale.git
echo.
echo 🎉 報告老闆：地址更新完成！已成功切換到 select-store！
echo ---------------------------------------------------
echo 請關閉這個黑畫面。現在你可以放心去點「啟動盤點系統.bat」了。
echo.
pause