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

# 🔥 實作置頂最多 2 個的防呆機制
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
        # 依照順序壓入標籤
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
        $bmp = [System.Drawing.Image]::FromFile($Path); $maxWidth = 350; $width = $bmp.Width; $height = $bmp.Height
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

# 🔥 純淨 HTML/JS 模板 (加入置頂 UI)
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
        
        .top-nav { background: rgba(26, 26, 26, 0.75); backdrop-filter: blur(16px); -webkit-backdrop-filter: blur(16px); position: sticky; top: 0; z-index: 100; border-bottom: 1px solid rgba(255,255,255,0.05); padding: 15px 10px; box-shadow: 0 4px 20px rgba(0,0,0,0.4); transition: transform 0.3s cubic-bezier(0.2, 0.8, 0.2, 1); }
        .search-box { width: 100%; max-width: 800px; margin: 0 auto 12px; display: block; padding: 10px 20px; border: 1px solid #444; border-radius: 25px; background: rgba(36, 36, 36, 0.9); color: #fff; box-sizing: border-box; font-size: 0.95rem; outline: none; transition: 0.3s; font-family: 'Noto Sans TC', sans-serif; }
        .search-box:focus { border-color: #3498db; background: #222; }
        
        .filter-container { display: flex; flex-direction: column; gap: 8px; width: 100%; max-width: 800px; margin: 0 auto; }
        .btn-group { display: flex; gap: 8px; width: 100%; overflow-x: auto; padding-bottom: 4px; scrollbar-width: none; -webkit-overflow-scrolling: touch; white-space: nowrap; }
        .btn-group::-webkit-scrollbar { display: none; }
        
        .filter-btn, .sort-btn { flex-shrink: 0; background: rgba(42, 42, 42, 0.8); border: 1px solid #444; padding: 6px 14px; border-radius: 20px; cursor: pointer; color: #ccc; font-size: 0.85rem; transition: 0.2s; font-family: 'Noto Sans TC', sans-serif; }
        .filter-btn.active { background: #3498db; color: white; border-color: #3498db; }
        .sort-btn { background: rgba(44, 62, 80, 0.8); border-color: #34495e; }
        .sort-btn.active { background: #e67e22; color: white; border-color: #e67e22; font-weight: bold; }

        @media (max-width: 600px) { .filter-divider { display: none; } }
        
        .grid-container { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; padding: 16px 12px; max-width: 1400px; margin: 0 auto; min-height: 400px; transition: all 0.4s cubic-bezier(0.2, 0.8, 0.2, 1); }
        body.search-focused .grid-container { filter: blur(5px) brightness(0.4); pointer-events: none; transform: scale(0.98); }
        
        .empty-state { grid-column: 1 / -1; display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 60px 10px; text-align: center; color: #888; animation: cardEnter 0.5s ease both; }
        .empty-state-icon { font-size: 3rem; margin-bottom: 12px; opacity: 0.6; }
        .empty-state h2 { font-size: 1.2rem; color: #ddd; margin: 0 0 8px; }
        .empty-state p { margin: 0 0 20px; font-size: 0.9rem; }
        .btn-reset { background: #3498db; color: #fff; border: none; padding: 10px 24px; border-radius: 24px; cursor: pointer; font-weight: bold; font-size: 0.9rem; transition: 0.2s; box-shadow: 0 4px 12px rgba(52, 152, 219, 0.3); font-family: 'Noto Sans TC', sans-serif; }

        /* 卡片設計 */
        .card { background: #1e1e24; display: flex; flex-direction: column; height: 100%; border-radius: 12px; border: 1px solid #2a2a2a; box-sizing: border-box; overflow: hidden; transition: transform 0.3s, box-shadow 0.3s, border-color 0.3s; padding: 12px; animation: cardEnter 0.6s cubic-bezier(0.2, 0.8, 0.2, 1) both; position: relative; }
        .card:hover { transform: translateY(-4px); box-shadow: 0 12px 32px rgba(0,0,0,0.5), inset 0 0 0 1px rgba(255,255,255,0.08); }
        @keyframes cardEnter { from { opacity: 0; transform: translateY(30px) scale(0.95); } to { opacity: 1; transform: translateY(0) scale(1); } }
        
        /* 🔥 A. 尊榮高調置頂 (電腦手機通用 CSS) */
        .card.pinned { 
            border-color: rgba(241, 196, 15, 0.5); 
            box-shadow: 0 4px 20px rgba(241, 196, 15, 0.08); 
        }
        .card.pinned:hover { 
            box-shadow: 0 12px 32px rgba(241, 196, 15, 0.2), inset 0 0 0 1px rgba(241, 196, 15, 0.6); 
        }
        /* 置頂標籤 - 放在圖片右上角 */
        .pin-badge { 
            position: absolute; top: 8px; right: 8px; 
            background: linear-gradient(135deg, #f1c40f, #e67e22); 
            color: #111; padding: 4px 10px; font-weight: 900; font-size: 0.75rem; 
            border-radius: 8px; z-index: 12; box-shadow: 0 4px 10px rgba(0,0,0,0.5); letter-spacing: 1px; 
        }
        
        .img-wrapper { width: 100%; position: relative; display: flex; justify-content: center; align-items: center; margin-bottom: 10px; }
        .main-img-container { width: 90%; max-width: 260px; aspect-ratio: 1/1; position: relative; border-radius: 8px; cursor: zoom-in; background: #1a1a1a; }
        .main-img { width: 100%; height: 100%; object-fit: contain; opacity: 0; transition: opacity 0.4s ease-in-out; }
        .main-img.loaded { opacity: 1; }
        
        .condition-badge { display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 0.65rem; font-weight: 700; letter-spacing: 0.5px; margin-bottom: 6px; }
        .badge-new { background: rgba(230, 126, 34, 0.15); color: #e67e22; border: 1px solid rgba(230, 126, 34, 0.4); }
        .badge-used { background: rgba(255, 255, 255, 0.08); color: #cccccc; border: 1px solid rgba(255, 255, 255, 0.2); }

        .thumb-overlay-container { position: absolute; bottom: 6px; left: 50%; transform: translateX(-50%); width: 90%; display: flex; justify-content: center; z-index: 10; }
        .thumb-scroll-area { display: flex; gap: 4px; background: rgba(20, 20, 20, 0.65); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); padding: 4px 8px; border-radius: 20px; align-items: center; border: 1px solid rgba(255, 255, 255, 0.15); box-shadow: 0 4px 12px rgba(0,0,0,0.5); overflow-x: auto; scrollbar-width: none; -ms-overflow-style: none; scroll-behavior: smooth; }
        .thumb-dot { flex-shrink: 0; width: 20px; height: 20px; background-size: cover; background-position: center; border-radius: 50%; cursor: pointer; filter: brightness(0.6) saturate(0.7); border: 2px solid transparent; transition: all 0.3s; background-color: #111; }
        .thumb-dot:hover { transform: scale(1.3); filter: brightness(1) saturate(1); z-index: 2; }
        .thumb-dot.active { filter: brightness(1) saturate(1); border-color: rgba(255, 255, 255, 0.9); box-shadow: 0 0 8px rgba(255, 255, 255, 0.4); transform: scale(1.15); }
        .thumb-scroll-area:hover .thumb-dot.active:not(:hover) { transform: scale(1); box-shadow: none; border-color: rgba(255, 255, 255, 0.4); }
        
        .sold-badge { display: none; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-10deg); background: rgba(231, 76, 60, 0.95); color: white; padding: 6px 14px; font-weight: 900; font-size: 1rem; border-radius: 6px; z-index: 15; border: 2px solid white; letter-spacing: 1px; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
        .sold-out .sold-badge { display: block; }
        .sold-out .main-img { filter: grayscale(100%); opacity: 0.4; }
        
        .info { flex-grow: 1; display: flex; flex-direction: column; padding: 0 0 10px 0; }
        h3 { margin: 0 0 6px 0; font-size: 0.85rem; color: #fff; line-height: 1.4; font-weight: 700; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; text-overflow: ellipsis; }
        
        .price-container { margin-bottom: 8px; display: flex; align-items: baseline; flex-wrap: wrap; gap: 6px; font-family: 'Noto Sans TC', sans-serif; }
        .currency { font-size: 0.7em; font-weight: 500; margin-right: 2px; }
        .price { color: #ff6b6b; font-weight: 900; font-size: 1.05rem; }
        .old-price { color: #888; text-decoration: line-through; font-size: 0.75rem; font-weight: 500; }
        .new-price { color: #ff6b6b; font-weight: 900; font-size: 1.05rem; background: rgba(255, 107, 107, 0.15); padding: 2px 6px; border-radius: 4px; }
        
        .desc { font-size: 0.8rem; color: #999; margin: 0 0 8px 0; line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; text-overflow: ellipsis; }
        .ref-link { font-size: 0.75rem; color: #3498db; text-decoration: none; font-weight: 600; margin-top: auto; display: inline-block; padding-top: 8px; border-top: 1px dashed #333; }
        
        .card-actions { margin-top: auto; }
        .btn-add { font-family: 'Noto Sans TC', sans-serif; background: #3498db; color: white; border: none; padding: 8px; border-radius: 6px; cursor: pointer; font-weight: bold; font-size: 0.85rem; width: 100%; transition: background 0.2s, transform 0.1s; display: flex; align-items: center; justify-content: center; gap: 4px; position: relative; overflow: hidden; }
        .btn-add::after { content: ''; position: absolute; top: 0; left: -100%; width: 50%; height: 100%; background: linear-gradient(to right, transparent, rgba(255,255,255,0.4), transparent); transform: skewX(-20deg); animation: shineSweep 3s infinite ease-in-out; }
        @keyframes shineSweep { 0% { left: -100%; } 20% { left: 200%; } 100% { left: 200%; } }
        .btn-add:active { transform: scale(0.96); }
        .btn-sold { background: #444 !important; color: #aaa !important; pointer-events: none; }
        .btn-sold::after { display: none; } 
        
        #lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.6); z-index: 9999; justify-content: center; align-items: center; flex-direction: column; overflow: hidden; }
        #lb-bg { position: absolute; top: 0; left: 0; width: 100%; height: 100%; background-size: cover; background-position: center; filter: blur(40px) brightness(0.4); z-index: -1; transform: scale(1.1); transition: background-image 0.4s ease-in-out; }
        #lightbox img { max-width: 90%; max-height: 85vh; object-fit: contain; z-index: 1; box-shadow: 0 10px 40px rgba(0,0,0,0.6); border-radius: 8px; }
        
        #lb-counter { position: absolute; top: 20px; left: 50%; transform: translateX(-50%); color: white; font-size: 1rem; font-weight: bold; background: rgba(0,0,0,0.6); padding: 4px 16px; border-radius: 20px; z-index: 10001; letter-spacing: 1px; backdrop-filter: blur(4px); }
        .lb-nav { position: absolute; top: 50%; transform: translateY(-50%); background: rgba(255,255,255,0.1); color: white; border: none; font-size: 1.5rem; width: 40px; height: 40px; display: flex; justify-content: center; align-items: center; cursor: pointer; border-radius: 50%; z-index: 10001; transition: 0.3s; backdrop-filter: blur(4px); }
        #lb-prev { left: 10px; }
        #lb-next { right: 10px; }
        #lb-close { position: absolute; top: 20px; right: 15px; background: rgba(255,255,255,0.1); width: 36px; height: 36px; border-radius: 50%; display: flex; justify-content: center; align-items: center; color: white; border: none; font-size: 1.2rem; cursor: pointer; z-index: 10001; backdrop-filter: blur(4px); }

        #toast { visibility: hidden; min-width: auto; background: rgba(30, 30, 30, 0.85); backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px); color: #fff; text-align: center; border-radius: 30px; padding: 10px 20px; position: fixed; z-index: 10000; left: 50%; bottom: 100px; font-size: 0.95rem; transform: translate(-50%, 20px); box-shadow: 0 10px 30px rgba(0,0,0,0.5); opacity: 0; transition: all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275); font-weight: bold; border: 1px solid rgba(255,255,255,0.1); pointer-events: none; display: flex; align-items: center; gap: 8px; white-space: nowrap; }
        #toast.show { visibility: visible; opacity: 1; transform: translate(-50%, 0); }
        
        .bottom-bar { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); width: calc(100% - 32px); max-width: 400px; display: flex; z-index: 1000; box-shadow: 0 10px 25px rgba(0,0,0,0.5); pointer-events: auto; border-radius: 30px; overflow: hidden; background: rgba(30,30,30,0.8); backdrop-filter: blur(10px); }
        .bottom-btn { font-family: 'Noto Sans TC', sans-serif; flex: 1; padding: 14px 0; text-align: center; font-size: 0.95rem; font-weight: bold; cursor: pointer; border: none; outline: none; text-decoration: none; color: white; }
        .btn-cart { background: linear-gradient(135deg, rgba(231, 76, 60, 0.95), rgba(192, 57, 43, 0.95)); border-right: 1px solid rgba(255,255,255,0.1); transform-origin: center center; }
        .btn-line { background: linear-gradient(135deg, rgba(6, 199, 85, 0.95), rgba(0, 179, 74, 0.95)); display: flex; align-items: center; justify-content: center; }
        
        @keyframes cartBounce { 0% { transform: scale(1); } 40% { transform: scale(1.1); } 70% { transform: scale(0.95); } 100% { transform: scale(1); } }
        .bounce-anim { animation: cartBounce 0.4s ease-in-out; }
        
        #btt-btn { position: fixed; bottom: 85px; right: 16px; width: 40px; height: 40px; border-radius: 50%; background: rgba(60, 60, 60, 0.75); color: #ddd; border: 1px solid rgba(255,255,255,0.1); cursor: pointer; box-shadow: 0 4px 12px rgba(0,0,0,0.3); z-index: 999; display: flex; justify-content: center; align-items: center; opacity: 0; pointer-events: none; transition: 0.3s; backdrop-filter: blur(6px); font-size: 1.1rem; }
        #btt-btn.show { opacity: 1; pointer-events: auto; }
        
        .modal-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px); z-index: 10005; display: flex; justify-content: center; align-items: flex-end; opacity: 0; pointer-events: none; transition: 0.3s; }
        .modal-overlay.show { opacity: 1; pointer-events: auto; }
        .modal-content { font-family: 'Noto Sans TC', sans-serif; background: #222; width: 100%; max-width: 500px; border-radius: 20px 20px 0 0; padding: 24px; box-sizing: border-box; transform: translateY(100%); transition: 0.4s cubic-bezier(0.2, 0.8, 0.2, 1); box-shadow: 0 -10px 30px rgba(0,0,0,0.5); display: flex; flex-direction: column; max-height: 85vh; }
        .modal-overlay.show .modal-content { transform: translateY(0); }
        .modal-header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #333; padding-bottom: 16px; margin-bottom: 16px; }
        .modal-header h2 { margin: 0; font-size: 1.2rem; color: #fff; font-weight: 700; }
        .close-btn { background: none; border: none; color: #888; font-size: 1.5rem; cursor: pointer; transition: 0.2s; }
        .close-btn:hover { color: #fff; }
        .modal-body { overflow-y: auto; flex-grow: 1; padding-right: 5px; }
        .modal-body::-webkit-scrollbar { width: 4px; }
        .checkout-item { display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px dashed #333; font-size: 0.95rem; color: #ddd; }
        .checkout-item-name { flex-grow: 1; padding-right: 15px; }
        .checkout-item-price { font-weight: bold; color: #ff6b6b; white-space: nowrap; }
        .modal-footer { margin-top: 16px; padding-top: 16px; border-top: 1px solid #333; }
        .modal-total { text-align: right; font-size: 1.4rem; color: #fff; font-weight: 900; margin-bottom: 16px; }
        .modal-total .currency { color: #ff6b6b; }
        .btn-confirm { width: 100%; background: #06C755; color: white; border: none; padding: 14px; border-radius: 12px; font-size: 1.05rem; font-weight: bold; cursor: pointer; transition: 0.2s; box-shadow: 0 4px 15px rgba(6, 199, 85, 0.3); font-family: 'Noto Sans TC', sans-serif; }

        /* 🖥️ 桌機版排版覆蓋 */
        @media (min-width: 768px) {
            body { padding-bottom: 0; }
            .grid-container { grid-template-columns: repeat(3, 1fr); gap: 24px; padding: 24px; }
            .card { padding: 18px; }
            h3 { font-size: 1.05rem; margin-bottom: 10px; }
            .price { font-size: 1.2rem; }
            .new-price { font-size: 1.2rem; padding: 3px 8px; }
            .old-price { font-size: 0.9rem; }
            .desc { font-size: 0.9rem; -webkit-line-clamp: 3; margin-bottom: 12px; }
            .condition-badge { font-size: 0.75rem; padding: 4px 10px; }
            .thumb-dot { width: 24px; height: 24px; }
            .btn-add { font-size: 1rem; padding: 12px; }
            
            .filter-container { flex-direction: row; justify-content: space-between; } 
            .btn-group { width: auto; overflow: visible; padding: 0; }
            
            .bottom-bar { bottom: 30px; right: 30px; left: auto; transform: none; width: auto; flex-direction: column; gap: 15px; box-shadow: none; background: transparent; backdrop-filter: none; }
            .bottom-btn { border-radius: 50px; padding: 14px 24px; box-shadow: 0 4px 15px rgba(0,0,0,0.4); border: none; flex: none; width: auto; font-size: 1.05rem; }
            .btn-cart { border-right: none; background: #e74c3c; }
            .btn-line { background: #06C755; }
            
            #btt-btn { bottom: 110px; right: 35px; width: 50px; height: 50px; font-size: 1.5rem; background: rgba(52, 152, 219, 0.9); border: none; }
            #toast { bottom: 40px; font-size: 1rem; padding: 12px 24px; } 
            
            .modal-overlay { align-items: center; }
            .modal-content { border-radius: 20px; transform: scale(0.9); }
            .modal-overlay.show .modal-content { transform: scale(1); }
            .lb-nav { width: 50px; height: 50px; font-size: 2rem; }
            #lb-close { width: 40px; height: 40px; font-size: 1.5rem; right: 20px; }
        }
        @media (min-width: 1200px) { .grid-container { grid-template-columns: repeat(4, 1fr); gap: 28px; } }
    </style>
</head><body>
    <div class="top-nav" id="top-nav">
        <input type="text" id="searchInput" class="search-box" placeholder="🔍 搜尋商品或描述...">
        <div class="filter-container">
            <div class="btn-group">
                <button class="filter-btn active" data-tag="all">全部</button>
                <button class="filter-btn" data-tag="未售出">#未售出</button>
                <button class="filter-btn" data-tag="已售出">#已售出</button>
                <button class="filter-btn" data-tag="全新">#全新</button>
                <button class="filter-btn" data-tag="二手">#二手</button>
            </div>
            <div class="btn-group">
                <button class="sort-btn active" data-sort="asc">價格低到高 ⭡</button>
                <button class="sort-btn" data-sort="desc">價格高到低 ⭣</button>
            </div>
        </div>
    </div>
    
    <div class="grid-container" id="productGrid"></div>
    
    <div class="bottom-bar">
        <button id="cartBtn" class="bottom-btn btn-cart" onclick="openCheckoutModal()">📝 結帳明細 (0件)</button>
        <a href="javascript:void(0)" onclick="openLine()" class="bottom-btn btn-line">💬 聯絡老闆 (LINE)</a>
    </div>

    <button id="btt-btn" onclick="window.scrollTo({top:0, behavior:'smooth'})">↑</button>

    <div id="checkout-modal" class="modal-overlay" onclick="closeCheckoutModal()">
        <div class="modal-content" onclick="event.stopPropagation()">
            <div class="modal-header">
                <h2>📝 確認結帳清單</h2>
                <button class="close-btn" onclick="closeCheckoutModal()">✕</button>
            </div>
            <div class="modal-body" id="checkout-list"></div>
            <div class="modal-footer">
                <div class="modal-total">總計：<span class="currency">NT$</span> <span id="checkout-total">0</span></div>
                <button class="btn-confirm" onclick="confirmAndCopy()">🚀 一鍵複製並聯絡老闆</button>
            </div>
        </div>
    </div>

    <div id="lightbox" onclick="closeBox(event)">
        <div id="lb-bg"></div>
        <div id="lb-counter" style="display:none;">1 / 3</div>
        <button id="lb-close" onclick="closeBox(event)">✕</button>
        <button id="lb-prev" class="lb-nav" onclick="lbNav(event, -1)" style="display:none;">❮</button>
        <div id="loading-text" style="color:white;font-weight:bold;font-size:1.2rem;display:none;">🔄 載入中...</div>
        <img id="box-img">
        <button id="lb-next" class="lb-nav" onclick="lbNav(event, 1)" style="display:none;">❯</button>
    </div>
    
    <div id="toast"></div>

    <script>
        const RAW_DATA = {{JSON}};
        let cart = {};
        let activeFilters = new Set();
        let activeSort = 'asc'; 
        let cardImgState = {};  
        let lbImages = [];
        let lbCurrentIdx = 0;
        
        let lastScrollY = window.scrollY;
        const topNav = document.getElementById('top-nav');
        
        document.getElementById('searchInput').addEventListener('focus', () => document.body.classList.add('search-focused'));
        document.getElementById('searchInput').addEventListener('blur', () => document.body.classList.remove('search-focused'));
        
        window.addEventListener('scroll', () => {
            const btt = document.getElementById('btt-btn');
            if (window.scrollY > 300) btt.classList.add('show');
            else btt.classList.remove('show');
            
            if (window.scrollY > 150 && window.scrollY > lastScrollY) {
                topNav.style.transform = 'translateY(-100%)';
            } else {
                topNav.style.transform = 'translateY(0)';
            }
            lastScrollY = window.scrollY;
        });

        function renderGrid() {
            const grid = document.getElementById('productGrid');
            grid.innerHTML = '';
            
            const search = document.getElementById('searchInput').value.toLowerCase();
            let filtered = [...RAW_DATA].filter(item => {
                const tags = (item.is_sold ? "已售出" : "未售出") + " " + item.desc + " " + item.name;
                const matchSearch = tags.toLowerCase().includes(search);
                const matchTag = activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.toLowerCase().includes(f.toLowerCase()));
                return matchSearch && matchTag;
            });
            
            // 🔥 排序邏輯加入「置頂優先」
            filtered.sort((a, b) => {
                if (a.is_pinned !== b.is_pinned) {
                    return a.is_pinned ? -1 : 1; 
                }
                if (activeSort === 'asc') return a.num_price - b.num_price;
                if (activeSort === 'desc') return b.num_price - a.num_price;
                return 0;
            });

            if (filtered.length === 0) {
                grid.innerHTML = `
                    <div class="empty-state">
                        <div class="empty-state-icon">📦</div>
                        <h2>Oops！找不到商品</h2>
                        <p>試試看其他關鍵字，或是換個篩選條件吧！</p>
                        <button class="btn-reset" onclick="resetFilters()">清除所有篩選</button>
                    </div>
                `;
                return;
            }

            filtered.forEach((item, renderIndex) => {
                const rawIdx = RAW_DATA.indexOf(item); 
                if(cardImgState[rawIdx] === undefined) cardImgState[rawIdx] = 0; 
                let currentImgIdx = cardImgState[rawIdx];

                const card = document.createElement('div');
                card.className = 'card';
                if (item.is_sold) card.classList.add('sold-out');
                // 🔥 加入置頂的專屬 class
                if (item.is_pinned) card.classList.add('pinned');
                card.style.animationDelay = `${Math.min(renderIndex * 0.05, 0.4)}s`;
                
                const priceHtml = item.sale_price 
                    ? `<span class="old-price"><span class="currency">NT$</span>${item.price}</span><span class="new-price">🔥 <span class="currency">NT$</span>${item.sale_price}</span>` 
                    : `<span class="price"><span class="currency">NT$</span>${item.price}</span>`;
                const urlHtml = item.url ? `<a href="${item.url}" target="_blank" class="ref-link">🔗 參考網址</a>` : '';
                
                let conditionBadge = '';
                if (item.desc.includes('全新')) {
                    conditionBadge = `<span class="condition-badge badge-new">✨ 全新</span>`;
                } else if (item.desc.includes('二手')) {
                    conditionBadge = `<span class="condition-badge badge-used">♻️ 二手</span>`;
                }
                let titleHtml = conditionBadge ? `<div>${conditionBadge}</div>` : '';

                // 🔥 置頂標籤
                let pinBadge = item.is_pinned ? `<div class="pin-badge">🔥 精選</div>` : '';

                let thumbHtml = '';
                if (item.images.length > 1) {
                    thumbHtml = `
                        <div class="thumb-overlay-container" onclick="event.stopPropagation()">
                            <div class="thumb-scroll-area">
                                ${item.images.map((img, i) => `<div class="thumb-dot ${i === currentImgIdx ? 'active' : ''}" style="background-image:url('${img}')" onclick="setMainImg(event, ${rawIdx}, ${i})"></div>`).join('')}
                            </div>
                        </div>`;
                }

                let btnText = cart[item.name] ? '✅ 已加入' : '➕ 加入清單';
                let btnHtml = item.is_sold 
                    ? `<button class="btn-add btn-sold" onclick="showToast('此商品已售出，下次請早！', '🚫')">🚫 已售出</button>`
                    : `<button class="btn-add" onclick="toggleCart('${item.name.replace(/'/g, "\\'")}', ${item.num_price}, this)" style="background:${cart[item.name] ? '#e67e22' : '#3498db'}">${btnText}</button>`;

                card.innerHTML = `
                    <div class="img-wrapper">
                        <div class="main-img-container" onclick="openBox(${rawIdx})">
                            ${pinBadge}
                            <div class="sold-badge">售出</div>
                            <img class="main-img" id="main-img-${rawIdx}" src="${item.images[currentImgIdx]}" onload="this.classList.add('loaded')">
                        </div>
                        ${thumbHtml}
                    </div>
                    <div class="info">
                        ${titleHtml}
                        <h3>${item.name}</h3>
                        <div class="price-container">${priceHtml}</div>
                        <p class="desc">${item.desc}</p>
                        ${urlHtml}
                    </div>
                    <div class="card-actions">
                        ${btnHtml}
                    </div>
                `;
                grid.appendChild(card);
            });
        }

        window.resetFilters = function() {
            document.getElementById('searchInput').value = '';
            activeFilters.clear();
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            document.querySelector('[data-tag="all"]').classList.add('active');
            renderGrid();
        }

        window.setMainImg = function(e, rawIdx, imgIdx) {
            e.stopPropagation();
            if(cardImgState[rawIdx] === imgIdx) return; 
            cardImgState[rawIdx] = imgIdx;
            let imgEl = document.getElementById('main-img-' + rawIdx);
            
            imgEl.classList.remove('loaded');
            setTimeout(() => {
                imgEl.src = RAW_DATA[rawIdx].images[imgIdx];
            }, 150);
            
            let overlay = e.target.closest('.thumb-scroll-area');
            if(overlay) {
                overlay.querySelectorAll('.thumb-dot').forEach(d => d.classList.remove('active'));
                
                let targetDot = e.target;
                targetDot.classList.add('active');
                
                let scrollLeft = targetDot.offsetLeft - overlay.offsetWidth / 2 + targetDot.offsetWidth / 2;
                overlay.scrollTo({ left: scrollLeft, behavior: 'smooth' });
            }
        }

        window.openBox = function(rawIdx) {
            let item = RAW_DATA[rawIdx];
            lbImages = item.images.map((b64, i) => item.highres[i] ? item.highres[i] : b64);
            lbCurrentIdx = cardImgState[rawIdx];
            document.getElementById('lightbox').style.display = 'flex';
            updateLbImage();
        }
        
        function updateLbImage() {
            let bImg = document.getElementById('box-img');
            let loader = document.getElementById('loading-text');
            let counter = document.getElementById('lb-counter');
            let lbBg = document.getElementById('lb-bg');
            
            bImg.style.display = 'none'; loader.style.display = 'block';
            
            if (lbImages.length > 1) {
                counter.style.display = 'block';
                counter.innerText = (lbCurrentIdx + 1) + ' / ' + lbImages.length;
                document.getElementById('lb-prev').style.display = 'flex';
                document.getElementById('lb-next').style.display = 'flex';
            } else {
                counter.style.display = 'none';
                document.getElementById('lb-prev').style.display = 'none';
                document.getElementById('lb-next').style.display = 'none';
            }
            
            let src = lbImages[lbCurrentIdx];
            lbBg.style.backgroundImage = `url('${src}')`;

            let tmp = new Image();
            tmp.onload = () => { bImg.src = src; loader.style.display = 'none'; bImg.style.display = 'block'; };
            tmp.onerror = () => { bImg.src = src; loader.style.display = 'none'; bImg.style.display = 'block'; };
            tmp.src = src;
        }

        window.lbNav = function(e, step) {
            e.stopPropagation();
            lbCurrentIdx = (lbCurrentIdx + step + lbImages.length) % lbImages.length;
            updateLbImage();
        }
        window.closeBox = function(e) {
            if(e.target.id === 'lightbox' || e.target.id === 'lb-close' || e.target.id === 'lb-bg') {
                document.getElementById('lightbox').style.display = 'none';
            }
        }

        function toggleCart(name, price, btn) {
            event.stopPropagation();
            if (cart[name]) { 
                delete cart[name]; 
                showToast('已從清單移除', '🗑️');
            } else { 
                cart[name] = price; 
                showToast('成功加入清單', '✅');
            }
            renderGrid();
            
            let count = Object.keys(cart).length;
            let cartBtn = document.getElementById('cartBtn');
            cartBtn.innerText = '📝 結帳明細 (' + count + '件)';
            
            cartBtn.classList.remove('bounce-anim');
            void cartBtn.offsetWidth; 
            cartBtn.classList.add('bounce-anim');
        }

        function openLine() {
            let isDesktop = !/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
            let rawId = "{{LINE_ID}}".trim();
            if (isDesktop && rawId !== "") {
                let lineUrl = rawId.startsWith('@') ? 'line://ti/p/' + rawId : 'line://ti/p/~' + rawId;
                window.location.href = lineUrl;
            } else {
                window.location.href = '{{LINE_LINK}}';
            }
        }

        function animateCounter(id, endVal, duration) {
            let obj = document.getElementById(id);
            let startTime = null;
            function step(currentTime) {
                if (!startTime) startTime = currentTime;
                let progress = Math.min((currentTime - startTime) / duration, 1);
                let easeOut = 1 - Math.pow(1 - progress, 3); 
                obj.innerText = Math.floor(easeOut * endVal).toLocaleString();
                if (progress < 1) requestAnimationFrame(step);
                else obj.innerText = endVal.toLocaleString();
            }
            requestAnimationFrame(step);
        }

        window.openCheckoutModal = function() {
            let items = Object.keys(cart);
            if (items.length === 0) { showToast('🛒 您的購物車是空的，請先挑選喔！', '📦'); return; }

            let listHtml = '';
            let total = 0;
            items.forEach((name, idx) => {
                let p = parseInt(cart[name]);
                total += p;
                listHtml += `<div class="checkout-item"><span class="checkout-item-name">${idx+1}. ${name}</span><span class="checkout-item-price"><span class="currency">NT$</span>${p.toLocaleString()}</span></div>`;
            });
            
            document.getElementById('checkout-list').innerHTML = listHtml;
            document.getElementById('checkout-modal').classList.add('show');
            document.body.style.overflow = 'hidden'; 
            
            animateCounter('checkout-total', total, 800);
        }

        window.closeCheckoutModal = function() {
            document.getElementById('checkout-modal').classList.remove('show');
            document.body.style.overflow = '';
        }

        window.confirmAndCopy = function() {
            let items = Object.keys(cart);
            let text = "【我要購買以下商品】\n";
            let total = 0;
            for(let i=0; i<items.length; i++) {
                let p = cart[items[i]];
                text += (i+1) + ". " + items[i] + " - NT$ " + p + "\n";
                total += parseInt(p);
            }
            text += "------------------\n總金額：NT$ " + total;

            navigator.clipboard.writeText(text).then(() => {
                closeCheckoutModal();
                alert("💡 貼心小提醒：\n\n【購買明細與金額】已經為您複製好囉！\n\n跳轉到 LINE 之後，請記得在對話框【長按 ➜ 選擇貼上】，傳送給老闆才算完成訂單喔！");
                openLine();
            }).catch(err => {
                closeCheckoutModal();
                alert("❌ 瀏覽器封鎖複製功能，請手動記下商品傳給老闆。");
            });
        }

        function showToast(msg, icon = '🔔') { 
            let t = document.getElementById('toast'); 
            t.innerHTML = `<span style="font-size:1.2rem">${icon}</span> <span>${msg}</span>`;
            t.classList.add('show'); 
            setTimeout(() => t.classList.remove('show'), 2500); 
        }
        
        document.getElementById('searchInput').addEventListener('input', renderGrid);
        
        document.querySelectorAll('.filter-btn').forEach(btn => { 
            btn.addEventListener('click', function() { 
                const tag = this.dataset.tag; 
                if (tag === 'all') { activeFilters.clear(); document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active')); this.classList.add('active'); } 
                else { document.querySelector('[data-tag="all"]').classList.remove('active'); if (activeFilters.has(tag)) { activeFilters.delete(tag); this.classList.remove('active'); } else { activeFilters.add(tag); this.classList.add('active'); } } 
                renderGrid(); 
            }); 
        });

        document.querySelectorAll('.sort-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                document.querySelectorAll('.sort-btn').forEach(b => b.classList.remove('active'));
                this.classList.add('active');
                activeSort = this.dataset.sort;
                renderGrid();
            });
        });

        renderGrid();
    </script>
</body></html>
'@

$FinalHtml = $HtmlTemplate.Replace('{{JSON}}', $JsonString).Replace('{{TITLE}}', $ShopTitle).Replace('{{LINE_LINK}}', $LineLink).Replace('{{LINE_ID}}', $LineID)
[System.IO.File]::WriteAllText((Join-Path $ScriptDir "index.html"), $FinalHtml, [System.Text.Encoding]::UTF8)

try {
    Write-Host "開始上傳至 GitHub..." -ForegroundColor Cyan
    git add . ; git commit -m "Feature: Pinned Items with Responsive Premium UI" ; git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 大功告成！置頂功能已經完美實裝，趕快去勾選看看吧！", 64, "功能上線")
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("⚠️ 上傳 GitHub 失敗！", 48, "警告")
}