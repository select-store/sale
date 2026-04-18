# 🛡️ 暴力路徑鎖定：確保讀寫絕對在當前資料夾
$ScriptDir = $PWD.Path
if ($PSScriptRoot) { $ScriptDir = $PSScriptRoot }
Set-Location -Path $ScriptDir

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# ================= 設定區 =================
$LineLink = "https://lin.ee/7NldLO6"
$ImageFolder = Join-Path $ScriptDir "images"
$CsvPath = Join-Path $ScriptDir "items.csv"
$ShopTitle = "📦 質感小物出清"
$ShopDesc  = "全新與二手好物特賣，點擊進來挖寶！"
$SiteUrl   = "https://select-store.github.io/sale/" 
# =========================================

if (Test-Path $CsvPath) {
    try { Set-ItemProperty -Path $CsvPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue } catch {}
}

# 1. 嚴格讀取舊資料庫
$ExistingItems = @()
$ExistingMap = @{}
if (Test-Path $CsvPath) {
    try {
        $RawItems = Import-Csv -Path $CsvPath -Encoding UTF8 -ErrorAction Stop
        foreach ($Item in $RawItems) {
            if (-not [string]::IsNullOrWhiteSpace($Item.name) -and -not $ExistingMap.ContainsKey($Item.name)) {
                $CleanPaths = @()
                if ($Item.image) {
                    foreach ($p in ($Item.image -split '\|')) {
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
        [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 無法讀取 items.csv！檔案可能被 Excel 鎖死。", 48, "錯誤")
        exit
    }
}

# 2. 建立 DNA 記憶字典
$DnaMap = @{}
foreach ($Item in $ExistingItems) {
    if (-not [string]::IsNullOrWhiteSpace($Item.image)) {
        foreach ($p in ($Item.image -split '\|')) {
            $fname = [System.IO.Path]::GetFileName($p).ToLower()
            if ($fname) { $DnaMap[$fname] = $Item }
        }
    }
}

# 3. 掃描照片
$Photos = @()
$SeenFiles = @{}
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

# 4. 核心建檔邏輯
$NewItems = @()
$ProcessedNames = @{} 

foreach ($Key in $GroupedProducts.Keys) {
    $GroupedImages = $GroupedProducts[$Key]
    $GroupedFileNames = $GroupedImages | ForEach-Object { [System.IO.Path]::GetFileName($_).ToLower() }
    
    $MatchedItem = $null
    foreach ($fname in $GroupedFileNames) {
        if ($DnaMap.ContainsKey($fname)) { $MatchedItem = $DnaMap[$fname]; break }
    }
    if ($null -eq $MatchedItem -and $ExistingMap.ContainsKey($Key)) { $MatchedItem = $ExistingMap[$Key] }
    
    if ($null -ne $MatchedItem) {
        if (-not $ProcessedNames.ContainsKey($MatchedItem.name)) {
            $OldImages = if($MatchedItem.image) { $MatchedItem.image -split '\|' } else { @() }
            $MergedImages = $OldImages + $GroupedImages | Select-Object -Unique
            $MatchedItem.image = ($MergedImages -join "|")
            $NewItems += $MatchedItem
            $ProcessedNames[$MatchedItem.name] = $true
        }
    } else {
        $formIn = New-Object System.Windows.Forms.Form
        $formIn.Text = "🆕 發現未建檔照片：$Key"; $formIn.Size = New-Object System.Drawing.Size(420, 600); $formIn.StartPosition = "CenterScreen"; $formIn.Font = New-Object System.Drawing.Font("微軟正黑體", 10)
        $startX = 20; $boxWidth = 360
        
        $addLbl = { param($t, $y) $l = New-Object System.Windows.Forms.Label; $l.Text=$t; $l.Location=New-Object System.Drawing.Point($startX, $y); $l.AutoSize=$true; $formIn.Controls.Add($l) }
        $addTxt = { param($v, $y, $h=30) $t = New-Object System.Windows.Forms.TextBox; $t.Text=$v; $t.Location=New-Object System.Drawing.Point($startX, ($y+22)); $t.Size=New-Object System.Drawing.Size($boxWidth, $h); if($h -gt 30){$t.Multiline=$true}; $formIn.Controls.Add($t); return $t }
        
        &$addLbl "👉 請選擇這張照片是哪個商品？" 10
        $lb = New-Object System.Windows.Forms.ListBox
        $lb.Location = New-Object System.Drawing.Point($startX, 35); $lb.Size = New-Object System.Drawing.Size($boxWidth, 80)
        $lb.Items.Add("✨ [這是一個全新商品，我要自己填]") | Out-Null
        foreach ($name in $ExistingMap.Keys) { $lb.Items.Add($name) | Out-Null }
        $lb.SelectedIndex = 0
        $formIn.Controls.Add($lb)

        &$addLbl "商品名稱 (Name)" 125;   $tName = &$addTxt $Key 125
        &$addLbl "原價 (Price)" 185;      $tPrice = &$addTxt "100" 185
        &$addLbl "特價 (Sale Price - 選填)" 245; $tSale = &$addTxt "" 245
        &$addLbl "商品描述 (Description)" 305;   $tDesc = &$addTxt "全新/二手出清。" 305 60
        &$addLbl "參考網址 (URL - 選填)" 395;    $tUrl = &$addTxt "" 395

        $lb.add_SelectedIndexChanged({
            if ($lb.SelectedIndex -eq 0) {
                $tName.Text = $Key; $tPrice.Text = "100"; $tSale.Text = ""; $tDesc.Text = "全新/二手出清。"; $tUrl.Text = ""
                $tName.Enabled = $true; $tPrice.Enabled = $true; $tSale.Enabled = $true; $tDesc.Enabled = $true; $tUrl.Enabled = $true
            } else {
                $selName = $lb.SelectedItem.ToString()
                $oldData = $ExistingMap[$selName]
                $tName.Text = $oldData.name; $tPrice.Text = $oldData.price; $tSale.Text = $oldData.sale_price; $tDesc.Text = $oldData.desc; $tUrl.Text = $oldData.url
                $tName.Enabled = $false; $tPrice.Enabled = $false; $tSale.Enabled = $false; $tDesc.Enabled = $false; $tUrl.Enabled = $false
            }
        })

        $btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text="💾 儲存這張照片"; $btnSave.Location="130,480"; $btnSave.Size="150,45"; $btnSave.BackColor="LightGreen"; $btnSave.DialogResult="OK"
        $formIn.Controls.Add($btnSave); $formIn.AcceptButton = $btnSave
        
        if ($formIn.ShowDialog() -eq "OK") { 
            if ($lb.SelectedIndex -eq 0) {
                $newItem = [PSCustomObject]@{ name=$tName.Text.Trim(); price=$tPrice.Text; sale_price=$tSale.Text; desc=$tDesc.Text; url=$tUrl.Text; image=($GroupedImages -join "|") }
                $NewItems += $newItem
                $ProcessedNames[$newItem.name] = $true
                $ExistingMap[$newItem.name] = $newItem
            } else {
                $selName = $lb.SelectedItem.ToString()
                $targetItem = $ExistingMap[$selName]
                $OldImages = if($targetItem.image) { $targetItem.image -split '\|' } else { @() }
                $MergedImages = $OldImages + $GroupedImages | Select-Object -Unique
                $targetItem.image = ($MergedImages -join "|")
                
                if (-not $ProcessedNames.ContainsKey($targetItem.name)) {
                    $NewItems += $targetItem
                    $ProcessedNames[$targetItem.name] = $true
                }
            }
        } else { exit }
        $formIn.Dispose()
    }
}

# 🚀 絕對防護：無條件保留所有舊資料，絕不刪除！
foreach ($Item in $ExistingItems) {
    if (-not $ProcessedNames.ContainsKey($Item.name)) {
        $NewItems += $Item
        $ProcessedNames[$Item.name] = $true
    }
}

# ⭐️ 庫存盤點
$formStock = New-Object System.Windows.Forms.Form
$formStock.Text = "📦 庫存狀況調整 (打勾代表已售出)"; $formStock.Size = New-Object System.Drawing.Size(380, 500); $formStock.StartPosition = "CenterScreen"
$clb = New-Object System.Windows.Forms.CheckedListBox; $clb.Location="15,20"; $clb.Size="330,360"; $clb.CheckOnClick=$true
foreach ($Item in $NewItems) { [void]$clb.Items.Add($Item.name, ($Item.desc -match "\[售出\]")) }
$formStock.Controls.Add($clb)
$btnPub = New-Object System.Windows.Forms.Button; $btnPub.Text="🚀 儲存並發布"; $btnPub.Location="120,400"; $btnPub.Size="120,40"; $btnPub.BackColor="LightBlue"; $btnPub.DialogResult="OK"
$formStock.Controls.Add($btnPub)
if ($formStock.ShowDialog() -eq "OK") { 
    for ($i=0; $i -lt $clb.Items.Count; $i++) {
        $target = $NewItems | Where-Object { $_.name -eq $clb.Items[$i] }
        if ($clb.GetItemChecked($i)) { if($target.desc -notmatch "\[售出\]"){$target.desc = "[售出] " + $target.desc} }
        else { $target.desc = $target.desc -replace "\[售出\]\s*", "" }
    }
}
$formStock.Dispose()

try {
    $NewItems | Select-Object -Unique name, price, sale_price, desc, url, image | Export-Csv -Path $CsvPath -Encoding UTF8 -NoTypeInformation -Force -ErrorAction Stop
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 嚴重錯誤：無法儲存 items.csv！", 48, "寫入失敗"); exit
}

# ================= 網頁生成與壓縮 =================
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

$HtmlStart = @"
<!DOCTYPE html>
<html lang="zh-TW"><head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ShopTitle</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #121212; color: #eee; margin: 0; }
        .search-container { padding: 10px; background: #1e1e1e; position: sticky; top: 0; z-index: 100; border-bottom: 1px solid #333; }
        #searchInput { width: 100%; max-width: 800px; margin: 0 auto; display: block; padding: 14px 20px; border: 1px solid #444; border-radius: 25px; background: #222; color: #fff; box-sizing: border-box; font-size: 1rem; }
        .filter-container { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; padding: 15px 10px; }
        .filter-btn { background: #333; border: none; padding: 8px 16px; border-radius: 20px; cursor: pointer; color: #ccc; font-size: 0.9rem; }
        .filter-btn.active { background: #3498db; color: white; }
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
        .thumb-img:hover, .thumb-img.active { opacity: 1; border-color: #3498db; }
        .info { flex-grow: 1; display: flex; flex-direction: column; margin-top: 10px; }
        h3 { margin: 0 0 8px 0; font-size: 1.1rem; color: #fff; line-height: 1.3; }
        .price-container { margin-bottom: 8px; }
        .price { color: #e74c3c; font-weight: bold; font-size: 1.2rem; }
        .old-price { color: #777; text-decoration: line-through; font-size: 0.9rem; margin-right: 8px; }
        .new-price { color: #e74c3c; font-weight: bold; font-size: 1.2rem; background: rgba(231, 76, 60, 0.15); padding: 2px 8px; border-radius: 4px; }
        .desc { font-size: 0.9rem; color: #aaa; margin: 0 0 12px 0; line-height: 1.5; }
        .ref-link { font-size: 0.85rem; color: #3498db; text-decoration: none; font-weight: bold; margin-top: auto; display: inline-block; padding-top: 8px; border-top: 1px dashed #444; }
        .btn-copy { background: #3498db; color: white; border: none; padding: 14px; border-radius: 8px; cursor: pointer; font-weight: bold; font-size: 1rem; width: 100%; margin-top: 16px; transition: background 0.2s; }
        .btn-copy:hover { background: #2980b9; }
        .floating-line { position: fixed; bottom: 30px; right: 30px; background: #06C755; color: white; padding: 14px 24px; border-radius: 50px; text-decoration: none; font-weight: bold; z-index: 100; box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
        #lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 999; justify-content: center; align-items: center; flex-direction: column; }
        #lightbox img { max-width: 95%; max-height: 90vh; object-fit: contain; }
        #loading-text { color: white; font-weight: bold; margin-bottom: 20px; font-size: 1.2rem; display: none; }
    </style>
</head><body>
    <div class="search-container"><input type="text" id="searchInput" placeholder="🔍 搜尋商品或描述..."></div>
    <div class="filter-container">
        <button class="filter-btn active" data-tag="all">全部</button>
        <button class="filter-btn" data-tag="未售出">#未售出</button>
        <button class="filter-btn" data-tag="已售出">#已售出</button>
        <button class="filter-btn" data-tag="全新">#全新</button>
        <button class="filter-btn" data-tag="二手">#二手</button>
    </div>
    <div class="grid-container" id="productGrid">
"@

$CardsHtml = ""
foreach ($Item in $NewItems) {
    $IsSold = ($Item.desc -match "\[售出\]")
    $StatusTag = if ($IsSold) { "已售出" } else { "未售出" }
    $CardClass = if ($IsSold) { "card sold-out" } else { "card" }
    
    $FinalPrice = if ($Item.sale_price) { $Item.sale_price } else { $Item.price }
    $PriceHtml = if ($Item.sale_price) { "<div class=`"price-container`"><span class=`"old-price`">NT$ $($Item.price)</span><span class=`"new-price`">🔥 NT$ $($Item.sale_price)</span></div>" } else { "<div class=`"price-container`"><span class=`"price`">NT$ $($Item.price)</span></div>" }
    $UrlHtml = if ($Item.url) { "<a href=`"$($Item.url)`" target=`"_blank`" class=`"ref-link`">🔗 點此查看原廠參考網址</a>" } else { "" }

    $ImgPaths = $Item.image -split '\|'
    $Base64List = @()
    $HighResList = @()
    
    foreach ($p in $ImgPaths) {
        $absPath = Join-Path $ScriptDir $p
        $b = Optimize-ImageToBase64 -Path $absPath
        if ($b) { 
            $Base64List += $b
            $Rel = $p -replace "\\", "/"
            $HighResList += "$($SiteUrl)$($Rel)?v=$CacheBuster" 
        }
    }
    
    if ($Base64List.Count -eq 0) { 
        $Base64List += "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
        $HighResList += "" 
    }

    $MainBase64 = $Base64List[0]
    $MainHighRes = $HighResList[0]

    $ThumbHtml = ""
    if ($Base64List.Count -gt 1) {
        $ThumbHtml = "<div class='thumb-container'>"
        for ($i=0; $i -lt $Base64List.Count; $i++) { 
            $tB64 = $Base64List[$i]
            $tHR = $HighResList[$i]
            $ThumbHtml += "<img src='$tB64' data-highres='$tHR' class='thumb-img' onclick='changeImg(this)'>" 
        }
        $ThumbHtml += "</div>"
    }

    $BtnAction = if ($IsSold) { "alert('🚫 賣完囉！下次請早！')" } else { "copyInfo('$($Item.name)', '$FinalPrice', this)" }
    $BtnText = if ($IsSold) { "🚫 已售出" } else { "📋 複製購買資訊" }

    $CardsHtml += @"
    <div class="$CardClass" data-tags="$StatusTag $($Item.desc) $($Item.name)">
        <div class="main-img-container" onclick="openBox(this.querySelector('.main-img'))"><div class="sold-badge">已售出</div><img class="main-img" src="$MainBase64" data-highres="$MainHighRes"></div>
        $ThumbHtml
        <div class="info">
            <h3>$($Item.name)</h3>
            $PriceHtml
            <p class="desc">$($Item.desc)</p>
            $UrlHtml
        </div>
        <button class="btn-copy" onclick="$BtnAction">$BtnText</button>
    </div>
"@
}

$HtmlEnd = @"
    </div>
    <a href="$LineLink" class="floating-line" target="_blank">💬 聯繫我 (LINE)</a>
    <div id="lightbox" onclick="this.style.display='none'">
        <div id="loading-text">🔄 正在連線下載高清原圖...</div>
        <img id="box-img">
    </div>
    <script>
        function changeImg(t){ let m = t.closest('.card').querySelector('.main-img'); m.src=t.src; m.setAttribute('data-highres', t.getAttribute('data-highres')); }
        function openBox(img){ 
            let box = document.getElementById('lightbox'); let bImg = document.getElementById('box-img'); let loader = document.getElementById('loading-text'); let hr = img.getAttribute('data-highres');
            box.style.display='flex'; bImg.style.display='none';
            if(hr){ loader.style.display='block'; let tmp = new Image(); tmp.onload = () => { bImg.src=hr; loader.style.display='none'; bImg.style.display='block'; }; tmp.onerror = () => { bImg.src=img.src; loader.style.display='none'; bImg.style.display='block'; }; tmp.src=hr; } 
            else { bImg.src=img.src; bImg.style.display='block'; }
        }
        function copyInfo(n, p, b){ event.stopPropagation(); navigator.clipboard.writeText('【我要購買】'+n+'\n金額：NT$ '+p).then(() => { let old = b.innerText; b.innerText = '✅ 已複製！'; b.style.background = '#27ae60'; setTimeout(() => { b.innerText = old; b.style.background = '#3498db'; }, 2000); }); }
        let activeFilters = new Set();
        document.querySelectorAll('.filter-btn').forEach(btn => { btn.addEventListener('click', function() { const tag = this.dataset.tag; if (tag === 'all') { activeFilters.clear(); document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active')); this.classList.add('active'); } else { document.querySelector('[data-tag="all"]').classList.remove('active'); if (activeFilters.has(tag)) { activeFilters.delete(tag); this.classList.remove('active'); } else { activeFilters.add(tag); this.classList.add('active'); } } applyFilters(); }); });
        function applyFilters() { const search = document.getElementById('searchInput').value.toLowerCase(); document.querySelectorAll('.card').forEach(card => { const tags = card.dataset.tags.toLowerCase(); card.style.display = (tags.includes(search) && (activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.includes(f.toLowerCase())))) ? 'flex' : 'none'; }); }
        document.getElementById('searchInput').addEventListener('input', applyFilters);
    </script>
</body></html>
"@
$OutPath = Join-Path $ScriptDir "index.html"
[System.IO.File]::WriteAllText($OutPath, ($HtmlStart + $CardsHtml + $HtmlEnd), [System.Text.Encoding]::UTF8)

# ==== 🚀 自動上傳 GitHub ====
try {
    Write-Host "開始上傳至 GitHub..." -ForegroundColor Cyan
    git add .
    git commit -m "Auto-update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 完美發布！資料已全數保住，網頁已更新！", 64, "大功告成")
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("⚠️ 網頁已生成，但 GitHub 上傳失敗！", 48, "上傳警告")
}