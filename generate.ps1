# 🛡️ 暴力路徑鎖定
$ScriptDir = $PWD.Path
if ($PSScriptRoot) { $ScriptDir = $PSScriptRoot }
Set-Location -Path $ScriptDir

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Data

# ================= 設定區 =================
$LineLink = "https://lin.ee/7NldLO6"
$LineID   = "@917cytma" 

$ImageFolder = Join-Path $ScriptDir "images"
$CsvPath = Join-Path $ScriptDir "items.csv"
$ShopTitle = "📦 質感小物出清"
$SiteUrl   = "https://select-store.github.io/sale/" 
# =========================================

if (Test-Path $CsvPath) {
    try { Set-ItemProperty -Path $CsvPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue } catch {}
}

# 1. 讀取舊資料庫
$ExistingItems = @()
$ExistingMap = @{}
if (Test-Path $CsvPath) {
    try {
        $RawItems = Import-Csv -Path $CsvPath -Encoding UTF8 -ErrorAction Stop
        foreach ($Item in $RawItems) {
            if (-not [string]::IsNullOrWhiteSpace($Item.name) -and -not $ExistingMap.ContainsKey($Item.name)) {
                $CleanPaths = @()
                if ($Item.image) {
                    foreach ($p in @($Item.image -split '\|')) {
                        $fname = [System.IO.Path]::GetFileName($p)
                        if ($fname) { $CleanPaths += "images\$fname" }
                    }
                }
                $Item.image = $CleanPaths -join "|"
                $ExistingItems += $Item
                $ExistingMap[$Item.name] = $Item
            }
        }
    } catch {
        [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 無法讀取 items.csv！檔案可能被 Excel 鎖死。", 48, "錯誤"); exit
    }
}

# 2. 建立 DNA 字典 & 掃描新照片
$DnaMap = @{}
foreach ($Item in $ExistingItems) {
    if (-not [string]::IsNullOrWhiteSpace($Item.image)) {
        foreach ($p in @($Item.image -split '\|')) {
            $fname = [System.IO.Path]::GetFileName($p).ToLower()
            if ($fname) { $DnaMap[$fname] = $Item }
        }
    }
}

$Photos = @(); $SeenFiles = @{}
if (Test-Path $ImageFolder) { 
    $Found = Get-ChildItem -Path $ImageFolder -Include *.jpg,*.jpeg,*.png,*.gif -Recurse
    foreach ($img in $Found) {
        $FileNameKey = $img.Name.ToLower()
        if (-not $SeenFiles.ContainsKey($FileNameKey)) { $SeenFiles[$FileNameKey] = $true; $Photos += $img }
    }
} 

$GroupedProducts = @{}
foreach ($Photo in $Photos) {
    $ProductName = $Photo.BaseName -replace '[_\-\s0-9]+$', ''
    if ([string]::IsNullOrWhiteSpace($ProductName)) { $ProductName = $Photo.BaseName }
    if (-Not $GroupedProducts.ContainsKey($ProductName)) { $GroupedProducts[$ProductName] = @() }
    $GroupedProducts[$ProductName] += "images\$($Photo.Name)"
}

# 3. 建檔邏輯
$NewItems = @(); $ProcessedNames = @{} 
foreach ($Key in $GroupedProducts.Keys) {
    $GroupedImages = @($GroupedProducts[$Key])
    $GroupedFileNames = $GroupedImages | ForEach-Object { [System.IO.Path]::GetFileName($_).ToLower() }
    
    $MatchedItem = $null
    foreach ($fname in $GroupedFileNames) {
        if ($DnaMap.ContainsKey($fname)) { $MatchedItem = $DnaMap[$fname]; break }
    }
    if ($null -eq $MatchedItem -and $ExistingMap.ContainsKey($Key)) { $MatchedItem = $ExistingMap[$Key] }
    
    if ($null -ne $MatchedItem) {
        if (-not $ProcessedNames.ContainsKey($MatchedItem.name)) {
            $OldArray = if ($MatchedItem.image) { @($MatchedItem.image -split '\|') } else { @() }
            $MergedArray = @($OldArray) + $GroupedImages
            $MatchedItem.image = ($MergedArray | Select-Object -Unique | Where-Object { $_ -ne "" }) -join "|"
            $NewItems += $MatchedItem; $ProcessedNames[$MatchedItem.name] = $true
        }
    } else {
        $formIn = New-Object System.Windows.Forms.Form
        $formIn.Text = "🆕 發現未建檔照片：$Key"; $formIn.Size = "420,600"; $formIn.StartPosition = "CenterScreen"; $formIn.Font = New-Object System.Drawing.Font("微軟正黑體", 10)
        
        $addLbl = { param($t, $y) $l = New-Object System.Windows.Forms.Label; $l.Text=$t; $l.Location="20,$y"; $l.AutoSize=$true; $formIn.Controls.Add($l) }
        $addTxt = { param($v, $y, $h=30) $t = New-Object System.Windows.Forms.TextBox; $t.Text=$v; $t.Location="20,$($y+22)"; $t.Size="360,$h"; if($h -gt 30){$t.Multiline=$true}; $formIn.Controls.Add($t); return $t }
        
        &$addLbl "👉 請選擇這張照片是哪個商品？" 10
        $lb = New-Object System.Windows.Forms.ListBox; $lb.Location="20,35"; $lb.Size="360,80"
        $lb.Items.Add("✨ [這是一個全新商品，我要自己填]") | Out-Null
        foreach ($name in $ExistingMap.Keys) { $lb.Items.Add($name) | Out-Null }
        $lb.SelectedIndex = 0; $formIn.Controls.Add($lb)

        &$addLbl "商品名稱 (Name)" 125;   $tName = &$addTxt $Key 125
        &$addLbl "原價 (Price)" 185;      $tPrice = &$addTxt "100" 185
        &$addLbl "特價 (Sale Price)" 245; $tSale = &$addTxt "" 245
        &$addLbl "商品描述 (Description)" 305;   $tDesc = &$addTxt "全新/二手出清。" 305 60
        &$addLbl "參考網址 (URL)" 395;    $tUrl = &$addTxt "" 395

        $lb.add_SelectedIndexChanged({
            if ($lb.SelectedIndex -eq 0) {
                $tName.Text = $Key; $tPrice.Text = "100"; $tSale.Text = ""; $tDesc.Text = "全新/二手出清。"; $tUrl.Text = ""; $tName.Enabled = $true; $tPrice.Enabled = $true; $tSale.Enabled = $true; $tDesc.Enabled = $true; $tUrl.Enabled = $true
            } else {
                $oldData = $ExistingMap[$lb.SelectedItem.ToString()]
                $tName.Text = $oldData.name; $tPrice.Text = $oldData.price; $tSale.Text = $oldData.sale_price; $tDesc.Text = $oldData.desc; $tUrl.Text = $oldData.url; $tName.Enabled = $false; $tPrice.Enabled = $false; $tSale.Enabled = $false; $tDesc.Enabled = $false; $tUrl.Enabled = $false
            }
        })

        $btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text="💾 儲存照片"; $btnSave.Location="130,480"; $btnSave.Size="150,45"; $btnSave.BackColor="LightGreen"; $btnSave.DialogResult="OK"
        $formIn.Controls.Add($btnSave); $formIn.AcceptButton = $btnSave
        
        if ($formIn.ShowDialog() -eq "OK") { 
            if ($lb.SelectedIndex -eq 0) {
                $newItem = [PSCustomObject]@{ name=$tName.Text.Trim(); price=$tPrice.Text; sale_price=$tSale.Text; desc=$tDesc.Text; url=$tUrl.Text; image=($GroupedImages -join "|") }
                $NewItems += $newItem; $ProcessedNames[$newItem.name] = $true; $ExistingMap[$newItem.name] = $newItem
            } else {
                $targetItem = $ExistingMap[$lb.SelectedItem.ToString()]
                $OldArray = if ($targetItem.image) { @($targetItem.image -split '\|') } else { @() }
                $targetItem.image = (@($OldArray) + $GroupedImages | Select-Object -Unique | Where-Object { $_ -ne "" }) -join "|"
                if (-not $ProcessedNames.ContainsKey($targetItem.name)) { $NewItems += $targetItem; $ProcessedNames[$targetItem.name] = $true }
            }
        } else { exit }
        $formIn.Dispose()
    }
}
foreach ($Item in $ExistingItems) { if (-not $ProcessedNames.ContainsKey($Item.name)) { $NewItems += $Item; $ProcessedNames[$Item.name] = $true } }

# 4. 管理中心
$dt = New-Object System.Data.DataTable
$dt.Columns.Add("徹底刪除", [bool]) | Out-Null
$dt.Columns.Add("置頂", [bool]) | Out-Null
$dt.Columns.Add("售出", [bool]) | Out-Null
$dt.Columns.Add("商品名稱", [string]) | Out-Null
$dt.Columns.Add("原價", [string]) | Out-Null
$dt.Columns.Add("特價", [string]) | Out-Null
$dt.Columns.Add("商品描述", [string]) | Out-Null
$dt.Columns.Add("參考網址", [string]) | Out-Null
$dt.Columns.Add("圖片路徑", [string]) | Out-Null

foreach ($Item in $NewItems) {
    $row = $dt.NewRow()
    $row["徹底刪除"] = $false
    $row["置頂"] = ($Item.desc -match "\[置頂\]")
    $row["售出"] = ($Item.desc -match "\[售出\]")
    $row["商品名稱"] = $Item.name
    $row["原價"] = $Item.price
    $row["特價"] = $Item.sale_price
    $row["商品描述"] = $Item.desc -replace "\[售出\]\s*", "" -replace "\[置頂\]\s*", "" -replace "\[下架\]\s*", "" 
    $row["參考網址"] = $Item.url
    $row["圖片路徑"] = $Item.image
    $dt.Rows.Add($row)
}

$formManage = New-Object System.Windows.Forms.Form
$formManage.Text = "📊 商品管理中心 (打勾「徹底刪除」將把商品從資料庫永遠抹除！)"
$formManage.Size = "1100,600"; $formManage.StartPosition = "CenterScreen"; $formManage.Font = New-Object System.Drawing.Font("微軟正黑體", 10)
$grid = New-Object System.Windows.Forms.DataGridView; $grid.DataSource = $dt; $grid.Dock = "Fill"; $grid.AutoSizeColumnsMode = "Fill"; $grid.AllowUserToAddRows = $false; $grid.RowHeadersVisible = $false
$formManage.Controls.Add($grid)

$grid.add_CurrentCellDirtyStateChanged({
    if ($grid.IsCurrentCellDirty) { $grid.CommitEdit([System.Windows.Forms.DataGridViewDataErrorContexts]::Commit) }
})

$grid.add_CellValueChanged({
    param($sender, $e)
    if ($e.RowIndex -ge 0 -and $grid.Columns[$e.ColumnIndex].Name -eq "置頂") {
        $checkedCount = 0
        foreach ($r in $dt.Rows) {
            if ($r["置頂"] -eq $true) { $checkedCount++ }
        }
        if ($checkedCount -gt 2) {
            [Microsoft.VisualBasic.Interaction]::MsgBox("⚠️ 老闆，頂級版位很珍貴！最多只能置頂 2 個商品喔！", 48, "置頂數量限制")
            $dt.Rows[$e.RowIndex]["置頂"] = $false
        }
    }
})

$formManage.add_Shown({
    $grid.Columns["圖片路徑"].Visible = $false
    $grid.Columns["徹底刪除"].FillWeight = 35; $grid.Columns["徹底刪除"].DefaultCellStyle.BackColor = [System.Drawing.Color]::MistyRose
    $grid.Columns["置頂"].FillWeight = 25; $grid.Columns["置頂"].DefaultCellStyle.BackColor = [System.Drawing.Color]::LightYellow
    $grid.Columns["售出"].FillWeight = 25
    $grid.Columns["商品名稱"].FillWeight = 80
    $grid.Columns["原價"].FillWeight = 30
    $grid.Columns["特價"].FillWeight = 30
    $grid.Columns["商品描述"].FillWeight = 120
    $grid.Columns["參考網址"].FillWeight = 50
})

$panel = New-Object System.Windows.Forms.Panel; $panel.Dock = "Bottom"; $panel.Height = 60
$btnSaveManage = New-Object System.Windows.Forms.Button; $btnSaveManage.Text = "💾 存檔並發布網頁"; $btnSaveManage.Size = "200,40"; $btnSaveManage.Location = "450,10"; $btnSaveManage.BackColor = "LightBlue"; $btnSaveManage.DialogResult = "OK"
$panel.Controls.Add($btnSaveManage); $formManage.Controls.Add($panel); $formManage.AcceptButton = $btnSaveManage

if ($formManage.ShowDialog() -eq "OK") {
    $FinalItems = @() 
    foreach ($row in $dt.Rows) {
        if ($row["徹底刪除"] -eq $true) { continue }
        $finalDesc = $row["商品描述"].ToString()
        if ($row["置頂"]) { $finalDesc = "[置頂] " + $finalDesc }
        if ($row["售出"]) { $finalDesc = "[售出] " + $finalDesc }
        $FinalItems += [PSCustomObject]@{ name=$row["商品名稱"].ToString().Trim(); price=$row["原價"].ToString(); sale_price=$row["特價"].ToString(); desc=$finalDesc; url=$row["參考網址"].ToString(); image=$row["圖片路徑"].ToString() }
    }
    $NewItems = $FinalItems 
}
$formManage.Dispose()

$NewItems | Select-Object -Unique name, price, sale_price, desc, url, image | Export-Csv -Path $CsvPath -Encoding UTF8 -NoTypeInformation -Force

# ================= 網頁生成 (MVC 架構) =================
$CacheBuster = (Get-Date).ToString("yyyyMMddHHmmss")
function Optimize-ImageToBase64 {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return $null }
        $bmp = [System.Drawing.Image]::FromFile($Path); $maxWidth = 400; $width = $bmp.Width; $height = $bmp.Height
        if ($width -gt $maxWidth) { $ratio = $maxWidth / $width; $width = $maxWidth; $height = [int]($height * $ratio) }
        $newBmp = New-Object System.Drawing.Bitmap($width, $height); $g = [System.Drawing.Graphics]::FromImage($newBmp)
        $g.Clear([System.Drawing.Color]::White); $g.InterpolationMode = 7; $g.DrawImage($bmp, 0, 0, $width, $height)
        $ms = New-Object System.IO.MemoryStream; $newBmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $base64 = [System.Convert]::ToBase64String($ms.ToArray()); $g.Dispose(); $newBmp.Dispose(); $bmp.Dispose(); $ms.Dispose()
        return "data:image/jpeg;base64,$base64"
    } catch { return $null }
}

Write-Host "🔄 正在打包商品資料..." -ForegroundColor Yellow
$WebData = @()
foreach ($Item in $NewItems) {
    if ($Item.desc -match "\[下架\]") { continue }
    $IsSold = ($Item.desc -match "\[售出\]" -or $Item.desc -match "\[售完\]")
    $IsPinned = ($Item.desc -match "\[置頂\]")
    $FinalPrice = if ($Item.sale_price) { $Item.sale_price } else { $Item.price }
    $NumPrice = ($FinalPrice -replace '[^\d]', '')
    if ([string]::IsNullOrWhiteSpace($NumPrice)) { $NumPrice = "0" }

    $Base64List = @(); $HighResList = @()
    foreach ($p in ($Item.image -split '\|' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $absPath = Join-Path $ScriptDir $p; $b = Optimize-ImageToBase64 -Path $absPath
        if ($b) { $Base64List += $b; $HighResList += "$SiteUrl$($p -replace "\\", "/")?v=$CacheBuster" }
    }
    if ($Base64List.Count -eq 0) { $Base64List += "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"; $HighResList += "" }

    $WebData += [Ordered]@{
        name = $Item.name
        desc = $Item.desc -replace "\[售出\]\s*", "" -replace "\[置頂\]\s*", ""
        price = $Item.price
        sale_price = $Item.sale_price
        num_price = [int]$NumPrice
        is_sold = $IsSold
        is_pinned = $IsPinned
        url = $Item.url
        images = $Base64List
        highres = $HighResList
    }
}
$JsonString = $WebData | ConvertTo-Json -Depth 5 -Compress

# 🔥 純淨 HTML/JS 模板 (雙層導覽旗艦版)
$HtmlTemplate = @'
<!DOCTYPE html>
<html lang="zh-TW"><head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>{{TITLE}}</title>
    <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+TC:wght@400;500;700;900&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Noto Sans TC', -apple-system, BlinkMacSystemFont, sans-serif; background: #121212; color: #eee; margin: 0; padding-bottom: 90px; line-height: 1.5; scroll-behavior: smooth; }
        
        ::-webkit-scrollbar { width: 8px; height: 8px; }
        ::-webkit-scrollbar-track { background: #121212; }
        ::-webkit-scrollbar-thumb { background: #333; border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #555; }
        
        /* 🔥 A. 頂部豪華雙層設計 */
        .top-nav { background: rgba(26, 26, 26, 0.85); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); position: sticky; top: 0; z-index: 100; border-bottom: 1px solid rgba(255,255,255,0.05); padding: 12px 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.4); transition: transform 0.3s cubic-bezier(0.2, 0.8, 0.2, 1); }
        .nav-container { max-width: 1400px; margin: 0 auto; display: flex; flex-direction: column; gap: 12px; }
        
        /* 第一層：搜尋 */
        .search-row { display: flex; gap: 12px; align-items: center; width: 100%; }
        .search-box { flex: 1; min-width: 0; margin: 0; padding: 12px 20px; border: 1px solid #444; border-radius: 25px; background: rgba(36, 36, 36, 0.9); color: #fff; box-sizing: border-box; font-size: 1rem; outline: none; transition: 0.3s; font-family: 'Noto Sans TC', sans-serif; }
        .search-box:focus { border-color: #3498db; background: #222; }
        
        /* 手機版篩選按鈕 (電腦版會隱藏) */
        .btn-open-filter { flex-shrink: 0; background: #2a2a2a; color: #eee; border: 1px solid #555; border-radius: 25px; padding: 12px 20px; font-size: 0.95rem; cursor: pointer; font-family: 'Noto Sans TC', sans-serif; font-weight: bold; transition: 0.2s; display: flex; align-items: center; gap: 6px; }
        
        /* 第二層：電腦版專用篩選列 (手機隱藏) */
        .desktop-filter-bar { display: none; align-items: center; justify-content: space-between; gap: 20px; border-top: 1px solid rgba(255,255,255,0.05); padding-top: 10px; }
        .filter-group { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
        .filter-label { font-size: 0.85rem; color: #888; font-weight: bold; margin-right: 4px; }
        
        /* 標籤按鈕樣式 */
        .filter-btn, .sort-btn { background: rgba(42, 42, 42, 0.8); border: 1px solid #444; padding: 8px 16px; border-radius: 20px; cursor: pointer; color: #ccc; font-size: 0.9rem; transition: 0.2s; font-family: 'Noto Sans TC', sans-serif; }
        .filter-btn:hover, .sort-btn:hover { background: #333; border-color: #666; }
        .filter-btn.active { background: #3498db; color: white; border-color: #3498db; font-weight: bold; }
        .sort-btn.active { background: #e67e22; color: white; border-color: #e67e22; font-weight: bold; }

        /* 🔥 B. 底部篩選抽屜 (手機版保留) */
        #filter-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7); backdrop-filter: blur(4px); -webkit-backdrop-filter: blur(4px); z-index: 10002; opacity: 0; pointer-events: none; transition: 0.3s; }
        #filter-overlay.show { opacity: 1; pointer-events: auto; }
        #filter-drawer { position: fixed; bottom: 0; left: 0; width: 100%; background: #1e1e24; border-radius: 24px 24px 0 0; z-index: 10003; transform: translateY(100%); transition: transform 0.4s cubic-bezier(0.2, 0.8, 0.2, 1); padding: 24px; box-sizing: border-box; display: flex; flex-direction: column; gap: 20px; }
        #filter-drawer.show { transform: translateY(0); }
        .drawer-header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px dashed #444; padding-bottom: 16px; }
        .drawer-close { background: rgba(255,255,255,0.1); border: none; color: #fff; width: 36px; height: 36px; border-radius: 50%; font-size: 1.2rem; cursor: pointer; }

        /* 商品網格 */
        .grid-container { display: grid; grid-template-columns: 1fr; gap: 24px; padding: 16px; max-width: 1400px; margin: 0 auto; min-height: 400px; }
        .card { background: #1e1e24; display: flex; flex-direction: column; border-radius: 16px; border: 1px solid #2a2a2a; overflow: hidden; padding: 18px; position: relative; transition: 0.3s; }
        .card:hover { transform: translateY(-4px); box-shadow: 0 12px 32px rgba(0,0,0,0.5); }
        
        /* 圖片與標籤 */
        .img-wrapper { width: 100%; position: relative; display: flex; justify-content: center; margin-bottom: 16px; }
        .main-img-container { width: 100%; max-width: 350px; aspect-ratio: 1/1; position: relative; border-radius: 12px; cursor: zoom-in; background: #1a1a1a; }
        .main-img { width: 100%; height: 100%; object-fit: contain; opacity: 0; transition: opacity 0.4s; }
        .main-img.loaded { opacity: 1; }
        .status-row { display: flex; gap: 8px; margin-bottom: 10px; }
        .pin-badge { padding: 4px 10px; border-radius: 6px; font-weight: 700; font-size: 0.85rem; border: 1px solid #EE82EE; color: #EE82EE; background: rgba(238, 130, 238, 0.1); }
        .condition-badge { padding: 4px 10px; border-radius: 6px; font-size: 0.85rem; font-weight: 700; border: 1px solid #555; }
        .badge-new { color: #e67e22; border-color: rgba(230, 126, 34, 0.4); }

        /* 價格與資訊 */
        h3 { margin: 0 0 10px 0; font-size: 1.25rem; color: #fff; line-height: 1.4; }
        .price-container { margin-bottom: 12px; display: flex; align-items: baseline; gap: 8px; }
        .price { color: #ff6b6b; font-weight: 900; font-size: 1.4rem; }
        .old-price { color: #888; text-decoration: line-through; font-size: 1rem; }
        .new-price { color: #ff6b6b; font-weight: 900; font-size: 1.4rem; background: rgba(255, 107, 107, 0.15); padding: 4px 8px; border-radius: 6px; }
        .desc { font-size: 1rem; color: #aaa; margin: 0 0 16px 0; white-space: pre-line; }

        /* 按鈕與小撇步 */
        .btn-add { background: #3498db; color: white; border: none; padding: 14px; border-radius: 8px; cursor: pointer; font-weight: bold; width: 100%; }
        .btn-sold { background: #444 !important; color: #aaa !important; cursor: not-allowed; }

        /* 🖥️ 桌機大改造 (重點在此！) */
        @media (min-width: 900px) {
            .btn-open-filter { display: none; } /* 隱藏手機抽屜按鈕 */
            .desktop-filter-bar { display: flex; } /* 顯示雙層導覽列 */
            .top-nav { padding: 16px 24px; }
            .grid-container { grid-template-columns: repeat(3, 1fr); padding: 24px; }
            body { padding-bottom: 0; }
            
            /* 底部導覽列改到右下角 */
            .bottom-bar { position: fixed; bottom: 30px; right: 30px; left: auto; transform: none; width: auto; flex-direction: column; gap: 15px; background: transparent; backdrop-filter: none; }
            .bottom-btn { border-radius: 50px; padding: 14px 24px; width: 220px; box-shadow: 0 8px 20px rgba(0,0,0,0.5); }
        }
        @media (min-width: 1200px) { .grid-container { grid-template-columns: repeat(4, 1fr); } }
        
        /* 雜項：Toast & Lightbox */
        #toast { visibility: hidden; position: fixed; bottom: 100px; left: 50%; transform: translateX(-50%); background: rgba(30,30,30,0.9); padding: 12px 24px; border-radius: 30px; z-index: 10000; transition: 0.3s; opacity: 0; border: 1px solid #444; }
        #toast.show { visibility: visible; opacity: 1; transform: translate(-50%, -20px); }
        #lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 9999; justify-content: center; align-items: center; }
        #lightbox img { max-width: 90%; max-height: 85vh; object-fit: contain; }
    </style>
</head><body>
    <div class="top-nav" id="top-nav">
        <div class="nav-container">
            <div class="search-row">
                <input type="text" id="searchInput" class="search-box" placeholder="🔍 搜尋商品或描述...">
                <button class="btn-open-filter" onclick="openFilterDrawer()">⚙️ 篩選</button>
            </div>
            <div class="desktop-filter-bar">
                <div class="filter-group">
                    <span class="filter-label">標籤：</span>
                    <button class="filter-btn active" data-tag="all">全部</button>
                    <button class="filter-btn" data-tag="未售出">#未售出</button>
                    <button class="filter-btn" data-tag="已售出">#已售出</button>
                    <button class="filter-btn" data-tag="全新">#全新</button>
                    <button class="filter-btn" data-tag="二手">#二手</button>
                </div>
                <div class="filter-group">
                    <span class="filter-label">排序：</span>
                    <button class="sort-btn active" data-sort="asc">價格低到高 ⭡</button>
                    <button class="sort-btn" data-sort="desc">價格高到低 ⭣</button>
                </div>
            </div>
        </div>
    </div>
    
    <div id="filter-overlay" onclick="closeFilterDrawer()"></div>
    <div id="filter-drawer">
        <div class="drawer-header"><h3>⚙️ 篩選與排序</h3><button class="drawer-close" onclick="closeFilterDrawer()">✕</button></div>
        <div style="padding:10px 0">
            <div class="filter-label">標籤篩選</div>
            <div class="filter-group" style="margin-top:10px">
                <button class="filter-btn active" data-tag="all">全部</button>
                <button class="filter-btn" data-tag="未售出">#未售出</button>
                <button class="filter-btn" data-tag="已售出">#已售出</button>
                <button class="filter-btn" data-tag="全新">#全新</button>
                <button class="filter-btn" data-tag="二手">#二手</button>
            </div>
        </div>
        <button class="btn-add" style="margin-top:20px" onclick="closeFilterDrawer()">查看結果</button>
    </div>
    
    <div class="grid-container" id="productGrid"></div>
    
    <div class="bottom-bar">
        <button id="cartBtn" class="btn-add" style="background:#e74c3c" onclick="openCheckoutModal()">📝 結帳明細 (0件)</button>
        <button class="btn-add" style="background:#06C755" onclick="openLine()">💬 聯絡老闆 (LINE)</button>
    </div>

    <div id="lightbox" onclick="this.style.display='none'"><img id="box-img"></div>
    <div id="toast"></div>

    <script>
        const RAW_DATA = {{JSON}};
        let cart = {};
        let activeFilters = new Set();
        let activeSort = 'asc'; 
        
        // 搜尋與篩選邏輯
        function renderGrid() {
            const grid = document.getElementById('productGrid');
            grid.innerHTML = '';
            const search = document.getElementById('searchInput').value.toLowerCase();
            
            let filtered = RAW_DATA.filter(item => {
                const tags = (item.is_sold ? "已售出" : "未售出") + " " + item.desc + " " + item.name;
                const matchSearch = tags.toLowerCase().includes(search);
                const matchTag = activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.includes(f));
                return matchSearch && matchTag;
            });
            
            filtered.sort((a, b) => {
                if (a.is_pinned !== b.is_pinned) return a.is_pinned ? -1 : 1;
                return activeSort === 'asc' ? a.num_price - b.num_price : b.num_price - a.num_price;
            });

            filtered.forEach((item, idx) => {
                const card = document.createElement('div');
                card.className = 'card';
                if (item.is_sold) card.classList.add('sold-out');
                
                const priceHtml = item.sale_price 
                    ? `<span class="old-price">NT$${item.price}</span><span class="new-price">🔥 NT$${item.sale_price}</span>` 
                    : `<span class="price">NT$${item.price}</span>`;
                
                card.innerHTML = `
                    <div class="img-wrapper" onclick="openBox('${item.images[0]}')">
                        <div class="main-img-container"><img class="main-img" src="${item.images[0]}" onload="this.classList.add('loaded')"></div>
                    </div>
                    <div class="info">
                        <div class="status-row">${item.is_pinned ? '<span class="pin-badge">🔥精選</span>' : ''}</div>
                        <h3>${item.name}</h3>
                        <div class="price-container">${priceHtml}</div>
                        <p class="desc">${item.desc}</p>
                    </div>
                    <button class="btn-add ${item.is_sold ? 'btn-sold' : ''}" onclick="toggleCart('${item.name}', ${item.num_price}, this)">
                        ${item.is_sold ? '🚫 已售出' : (cart[item.name] ? '✅ 已加入' : '➕ 加入清單')}
                    </button>
                `;
                grid.appendChild(card);
            });
        }

        // 同步電腦版與手機版的按鈕狀態
        function syncButtons() {
            document.querySelectorAll('.filter-btn').forEach(btn => {
                const tag = btn.dataset.tag;
                if (tag === 'all') {
                    activeFilters.size === 0 ? btn.classList.add('active') : btn.classList.remove('active');
                } else {
                    activeFilters.has(tag) ? btn.classList.add('active') : btn.classList.remove('active');
                }
            });
            document.querySelectorAll('.sort-btn').forEach(btn => {
                btn.dataset.sort === activeSort ? btn.classList.add('active') : btn.classList.remove('active');
            });
        }

        // 綁定所有按鈕事件
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const tag = btn.dataset.tag;
                if (tag === 'all') activeFilters.clear();
                else activeFilters.has(tag) ? activeFilters.delete(tag) : activeFilters.add(tag);
                syncButtons();
                renderGrid();
            });
        });

        document.querySelectorAll('.sort-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                activeSort = btn.dataset.sort;
                syncButtons();
                renderGrid();
            });
        });

        function toggleCart(name, price, btn) {
            if (cart[name]) delete cart[name];
            else cart[name] = price;
            renderGrid();
            document.getElementById('cartBtn').innerText = `📝 結帳明細 (${Object.keys(cart).length}件)`;
            showToast(cart[name] ? '已加入清單' : '已移除商品');
        }

        function openFilterDrawer() { document.getElementById('filter-drawer').classList.add('show'); document.getElementById('filter-overlay').classList.add('show'); }
        function closeFilterDrawer() { document.getElementById('filter-drawer').classList.remove('show'); document.getElementById('filter-overlay').classList.remove('show'); }
        function openBox(src) { document.getElementById('box-img').src = src; document.getElementById('lightbox').style.display = 'flex'; }
        function showToast(msg) { const t = document.getElementById('toast'); t.innerText = msg; t.classList.add('show'); setTimeout(()=>t.classList.remove('show'), 2000); }
        function openLine() { window.location.href = "{{LINE_LINK}}"; }
        
        document.getElementById('searchInput').addEventListener('input', renderGrid);
        renderGrid();
    </script>
</body></html>
'@

$FinalHtml = $HtmlTemplate.Replace('{{JSON}}', $JsonString).Replace('{{TITLE}}', $ShopTitle).Replace('{{LINE_LINK}}', $LineLink).Replace('{{LINE_ID}}', $LineID)
[System.IO.File]::WriteAllText((Join-Path $ScriptDir "index.html"), $FinalHtml, [System.Text.Encoding]::UTF8)

try {
    Write-Host "開始上傳至 GitHub..." -ForegroundColor Cyan
    git add . ; git commit -m "UI Final: Desktop Double-Layer Nav + Luxury UI" ; git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 旗艦版雙層導覽列上線！電腦版已經可以享受直球對決的快感了！", 64, "旗艦版上線")
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("⚠️ 上傳 GitHub 失敗！", 48, "警告")
}