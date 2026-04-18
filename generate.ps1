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
    $row["售出"] = ($Item.desc -match "\[售出\]")
    $row["商品名稱"] = $Item.name
    $row["原價"] = $Item.price
    $row["特價"] = $Item.sale_price
    $row["商品描述"] = $Item.desc -replace "\[售出\]\s*", "" -replace "\[下架\]\s*", "" 
    $row["參考網址"] = $Item.url
    $row["圖片路徑"] = $Item.image
    $dt.Rows.Add($row)
}

$formManage = New-Object System.Windows.Forms.Form
$formManage.Text = "📊 商品管理中心 (打勾「徹底刪除」將把商品從資料庫永遠抹除！)"
$formManage.Size = "1050,600"; $formManage.StartPosition = "CenterScreen"; $formManage.Font = New-Object System.Drawing.Font("微軟正黑體", 10)
$grid = New-Object System.Windows.Forms.DataGridView; $grid.DataSource = $dt; $grid.Dock = "Fill"; $grid.AutoSizeColumnsMode = "Fill"; $grid.AllowUserToAddRows = $false; $grid.RowHeadersVisible = $false
$formManage.Controls.Add($grid)

$formManage.add_Shown({
    $grid.Columns["圖片路徑"].Visible = $false
    $grid.Columns["徹底刪除"].FillWeight = 35; $grid.Columns["徹底刪除"].DefaultCellStyle.BackColor = [System.Drawing.Color]::MistyRose
    $grid.Columns["售出"].FillWeight = 25
    $grid.Columns["商品名稱"].FillWeight = 80
    $grid.Columns["原價"].FillWeight = 30
    $grid.Columns["特價"].FillWeight = 30
    $grid.Columns["商品描述"].FillWeight = 120
    $grid.Columns["參考網址"].FillWeight = 50
})

$panel = New-Object System.Windows.Forms.Panel; $panel.Dock = "Bottom"; $panel.Height = 60
$btnSaveManage = New-Object System.Windows.Forms.Button; $btnSaveManage.Text = "💾 存檔並發布網頁"; $btnSaveManage.Size = "200,40"; $btnSaveManage.Location = "420,10"; $btnSaveManage.BackColor = "LightBlue"; $btnSaveManage.DialogResult = "OK"
$panel.Controls.Add($btnSaveManage); $formManage.Controls.Add($panel); $formManage.AcceptButton = $btnSaveManage

if ($formManage.ShowDialog() -eq "OK") {
    $FinalItems = @() 
    foreach ($row in $dt.Rows) {
        if ($row["徹底刪除"] -eq $true) { continue }
        $finalDesc = $row["商品描述"].ToString()
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
        desc = $Item.desc -replace "\[售出\]\s*", ""
        price = $Item.price
        sale_price = $Item.sale_price
        num_price = [int]$NumPrice
        is_sold = $IsSold
        url = $Item.url
        images = $Base64List
        highres = $HighResList
    }
}
$JsonString = $WebData | ConvertTo-Json -Depth 5 -Compress

# 🔥 單引號保護的純淨 HTML/JS 模板
$HtmlTemplate = @'
<!DOCTYPE html>
<html lang="zh-TW"><head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{TITLE}}</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #121212; color: #eee; margin: 0; padding-bottom: 80px; }
        .top-nav { background: #1e1e1e; position: sticky; top: 0; z-index: 100; border-bottom: 1px solid #333; padding: 15px 10px; }
        .search-box { width: 100%; max-width: 800px; margin: 0 auto 15px; display: block; padding: 14px 20px; border: 1px solid #444; border-radius: 25px; background: #222; color: #fff; box-sizing: border-box; font-size: 1rem; }
        
        .filter-container { display: flex; flex-wrap: wrap; gap: 10px; justify-content: center; align-items: center; max-width: 1000px; margin: 0 auto; }
        .btn-group { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }
        .filter-divider { width: 2px; height: 24px; background: #444; margin: 0 5px; border-radius: 2px; }
        
        .filter-btn { background: #333; border: none; padding: 8px 16px; border-radius: 20px; cursor: pointer; color: #ccc; font-size: 0.9rem; transition: 0.2s; }
        .filter-btn.active { background: #3498db; color: white; }
        
        /* 🔥 排序按鈕樣式 */
        .sort-btn { background: #2c3e50; border: none; padding: 8px 16px; border-radius: 20px; cursor: pointer; color: #ccc; font-size: 0.9rem; transition: 0.2s; }
        .sort-btn.active { background: #e67e22; color: white; font-weight: bold; }

        @media (max-width: 600px) { .filter-divider { display: none; } }
        
        .grid-container { display: grid; grid-template-columns: 1fr; gap: 16px; padding: 16px; max-width: 1600px; margin: 0 auto; }
        @media (min-width: 550px) { .grid-container { grid-template-columns: repeat(2, 1fr); gap: 16px; } }
        @media (min-width: 850px) { .grid-container { grid-template-columns: repeat(4, 1fr); gap: 20px; } }
        @media (min-width: 1200px) { .grid-container { grid-template-columns: repeat(6, 1fr); gap: 24px; } }
        
        .card { background: #1e1e1e; display: flex; flex-direction: column; height: 100%; padding: 16px; border-radius: 12px; border: 1px solid #333; box-sizing: border-box; }
        .main-img-container { width: 100%; aspect-ratio: 1/1; position: relative; overflow: hidden; background: #2c2c2c; border-radius: 8px; cursor: zoom-in; margin-bottom: 10px; }
        .main-img { width: 100%; height: 100%; object-fit: contain; }
        .sold-badge { display: none; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-15deg); background: rgba(231, 76, 60, 0.95); color: white; padding: 8px 20px; font-weight: bold; border-radius: 6px; z-index: 10; border: 2px solid white; pointer-events: none; letter-spacing: 2px; }
        .sold-out .sold-badge { display: block; }
        .sold-out .main-img { filter: grayscale(100%); opacity: 0.4; }
        .thumb-container { display: flex; gap: 6px; padding: 4px 0; overflow-x: auto; }
        .thumb-img { width: 42px; height: 42px; object-fit: cover; border-radius: 6px; cursor: pointer; opacity: 0.5; border: 2px solid transparent; }
        .thumb-img:hover { opacity: 1; border-color: #3498db; }
        .info { flex-grow: 1; display: flex; flex-direction: column; margin-top: 10px; }
        h3 { margin: 0 0 8px 0; font-size: 1.1rem; color: #fff; line-height: 1.3; }
        .price { color: #e74c3c; font-weight: bold; font-size: 1.2rem; }
        .old-price { color: #777; text-decoration: line-through; font-size: 0.9rem; margin-right: 8px; }
        .new-price { color: #e74c3c; font-weight: bold; font-size: 1.2rem; background: rgba(231, 76, 60, 0.15); padding: 2px 8px; border-radius: 4px; }
        .desc { font-size: 0.9rem; color: #aaa; margin: 0 0 12px 0; line-height: 1.5; white-space: pre-line; }
        .ref-link { font-size: 0.85rem; color: #3498db; text-decoration: none; font-weight: bold; margin-top: auto; display: inline-block; padding-top: 8px; border-top: 1px dashed #444; }
        .btn-add { background: #3498db; color: white; border: none; padding: 14px; border-radius: 8px; cursor: pointer; font-weight: bold; font-size: 1rem; width: 100%; margin-top: 16px; transition: background 0.2s; }
        .btn-add:hover { background: #2980b9; }
        
        #lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 9999; justify-content: center; align-items: center; flex-direction: column; }
        #lightbox img { max-width: 95%; max-height: 90vh; object-fit: contain; }
        #toast { visibility: hidden; min-width: 250px; background-color: rgba(30, 30, 30, 0.95); color: #fff; text-align: center; border-radius: 8px; padding: 14px 24px; position: fixed; z-index: 10000; left: 50%; bottom: 90px; font-size: 1.1rem; transform: translateX(-50%); box-shadow: 0 4px 12px rgba(0,0,0,0.5); opacity: 0; transition: opacity 0.3s; font-weight: bold; border: 1px solid #555; pointer-events: none; }
        #toast.show { visibility: visible; opacity: 1; }
        
        /* 底部導覽列 */
        .bottom-bar { position: fixed; bottom: 0; left: 0; width: 100%; display: flex; z-index: 1000; box-shadow: 0 -4px 15px rgba(0,0,0,0.5); pointer-events: none; }
        .bottom-btn { pointer-events: auto; flex: 1; padding: 18px 0; text-align: center; font-size: 1.1rem; font-weight: bold; cursor: pointer; border: none; outline: none; text-decoration: none; }
        .btn-cart { background: #e74c3c; color: white; transition: background 0.3s; border-right: 1px solid #c0392b; }
        .btn-line { background: #06C755; color: white; transition: background 0.3s; display: flex; align-items: center; justify-content: center; }
        
        @media (min-width: 768px) {
            body { padding-bottom: 0; }
            .bottom-bar { bottom: 30px; right: 30px; left: auto; width: auto; flex-direction: column; gap: 15px; box-shadow: none; }
            .bottom-btn { border-radius: 50px; padding: 15px 25px; box-shadow: 0 4px 12px rgba(0,0,0,0.5); border: none; flex: none; width: auto; }
            .btn-cart { border-right: none; }
        }
    </style>
</head><body>
    <div class="top-nav">
        <input type="text" id="searchInput" class="search-box" placeholder="🔍 搜尋商品或描述...">
        
        <div class="filter-container">
            <div class="btn-group">
                <button class="filter-btn active" data-tag="all">全部</button>
                <button class="filter-btn" data-tag="未售出">#未售出</button>
                <button class="filter-btn" data-tag="已售出">#已售出</button>
                <button class="filter-btn" data-tag="全新">#全新</button>
                <button class="filter-btn" data-tag="二手">#二手</button>
            </div>
            
            <div class="filter-divider"></div>
            
            <div class="btn-group">
                <button class="sort-btn active" data-sort="asc">價格由低到高</button>
                <button class="sort-btn" data-sort="desc">價格由高到低</button>
            </div>
        </div>
    </div>
    
    <div class="grid-container" id="productGrid"></div>
    
    <div class="bottom-bar">
        <button id="cartBtn" class="bottom-btn btn-cart" onclick="checkout()">📝 結帳明細 (0件)</button>
        <a href="javascript:void(0)" onclick="openLine()" class="bottom-btn btn-line">💬 聯絡老闆 (LINE)</a>
    </div>

    <div id="lightbox" onclick="this.style.display='none'">
        <div id="loading-text">🔄 正在連線下載高清原圖...</div>
        <img id="box-img">
    </div>
    <div id="toast"></div>

    <script>
        const RAW_DATA = {{JSON}};
        let cart = {};
        let activeFilters = new Set();
        let activeSort = 'asc'; // 🔥 預設就從最便宜排起
        
        function renderGrid() {
            const grid = document.getElementById('productGrid');
            grid.innerHTML = '';
            
            const search = document.getElementById('searchInput').value.toLowerCase();
            let filtered = RAW_DATA.filter(item => {
                const tags = (item.is_sold ? "已售出" : "未售出") + " " + item.desc + " " + item.name;
                const matchSearch = tags.toLowerCase().includes(search);
                const matchTag = activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.toLowerCase().includes(f.toLowerCase()));
                return matchSearch && matchTag;
            });
            
            // 排序邏輯
            if (activeSort === 'asc') filtered.sort((a,b) => a.num_price - b.num_price);
            if (activeSort === 'desc') filtered.sort((a,b) => b.num_price - a.num_price);

            filtered.forEach(item => {
                const card = document.createElement('div');
                card.className = item.is_sold ? 'card sold-out' : 'card';
                
                const priceHtml = item.sale_price 
                    ? `<span class="old-price">NT$ ${item.price}</span><span class="new-price">🔥 NT$ ${item.sale_price}</span>` 
                    : `<span class="price">NT$ ${item.price}</span>`;
                const urlHtml = item.url ? `<a href="${item.url}" target="_blank" class="ref-link">🔗 原廠參考網址</a>` : '';
                
                let thumbHtml = '';
                if (item.images.length > 1) {
                    thumbHtml = `<div class="thumb-container">` + 
                        item.images.map((img, i) => `<img src="${img}" data-highres="${item.highres[i]}" class="thumb-img" onclick="changeImg(this)">`).join('') + 
                        `</div>`;
                }

                let btnHtml = item.is_sold 
                    ? `<button class="btn-add" onclick="showToast('🚫 賣完囉！下次請早！')">🚫 已售出</button>`
                    : `<button class="btn-add" onclick="toggleCart('${item.name.replace(/'/g, "\\'")}', ${item.num_price}, this)" style="background:${cart[item.name] ? '#e67e22' : '#3498db'}">${cart[item.name] ? '✅ 已加入' : '➕ 加入購物車'}</button>`;

                card.innerHTML = `
                    <div class="main-img-container" onclick="openBox(this.querySelector('.main-img'))">
                        <div class="sold-badge">已售出</div>
                        <img class="main-img" src="${item.images[0]}" data-highres="${item.highres[0]}">
                    </div>
                    ${thumbHtml}
                    <div class="info">
                        <h3>${item.name}</h3>
                        <div class="price-container">${priceHtml}</div>
                        <p class="desc">${item.desc}</p>
                        ${urlHtml}
                    </div>
                    ${btnHtml}
                `;
                grid.appendChild(card);
            });
        }

        function toggleCart(name, price, btn) {
            event.stopPropagation();
            if (cart[name]) { delete cart[name]; } else { cart[name] = price; }
            renderGrid();
            let count = Object.keys(cart).length;
            document.getElementById('cartBtn').innerText = '📝 結帳明細 (' + count + '件)';
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

        function checkout() {
            let items = Object.keys(cart);
            if (items.length === 0) { showToast('🛒 您的購物車是空的，請先挑選商品喔！'); return; }
            let text = "【我要購買以下商品】\n";
            let total = 0;
            for(let i=0; i<items.length; i++) {
                let p = cart[items[i]];
                text += (i+1) + ". " + items[i] + " - NT$ " + p + "\n";
                total += parseInt(p);
            }
            text += "------------------\n總金額：NT$ " + total;
            navigator.clipboard.writeText(text).then(() => {
                let goLine = confirm("✅ 【購買清單與金額】已經自動複製好囉！\n\n👉 按下「確定」：為您打開 LINE\n👉 按下「取消」：留在本網頁繼續逛");
                if (goLine) {
                    alert("💡 貼心小提醒：\n\n跳轉到 LINE 之後，請記得在打字框【長按 ➜ 選擇貼上】，把購買明細傳給老闆才算完成喔！");
                    openLine();
                }
            }).catch(err => {
                alert("❌ 瀏覽器封鎖複製功能，請手動記下商品傳給老闆。");
            });
        }

        function showToast(msg) { let t = document.getElementById('toast'); t.innerText = msg; t.classList.add('show'); setTimeout(() => t.classList.remove('show'), 2000); }
        function changeImg(t){ let m = t.closest('.card').querySelector('.main-img'); m.src=t.src; m.setAttribute('data-highres', t.getAttribute('data-highres')); }
        function openBox(img){ 
            let box = document.getElementById('lightbox'), bImg = document.getElementById('box-img'), loader = document.getElementById('loading-text'), hr = img.getAttribute('data-highres');
            box.style.display='flex'; bImg.style.display='none';
            if(hr){ loader.style.display='block'; let tmp = new Image(); tmp.onload = () => { bImg.src=hr; loader.style.display='none'; bImg.style.display='block'; }; tmp.onerror = () => { bImg.src=img.src; loader.style.display='none'; bImg.style.display='block'; }; tmp.src=hr; } 
            else { bImg.src=img.src; bImg.style.display='block'; }
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
    git add . ; git commit -m "Update Sorting UI" ; git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 更新完成！價格排序按鈕已改版！", 64, "大功告成")
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("⚠️ 上傳 GitHub 失敗！", 48, "警告")
}