# 強制鎖定當前資料夾
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }
Set-Location -Path $ScriptPath

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# ================= 設定區 =================
$LineLink = "https://lin.ee/7NldLO6"
$ImageFolder = ".\images"
$CsvPath = ".\items.csv"
$ShopTitle = "📦 質感小物出清"
$ShopDesc  = "全新與二手好物特賣，點擊進來挖寶！"
$SiteUrl   = "https://select-store.github.io/sale/" 
# =========================================

# 🚀 掃描照片 (單一資料夾，濾除重複檔名)
$Photos = @()
$SeenFiles = @{}
if (Test-Path $ImageFolder) { 
    $Found = Get-ChildItem -Path $ImageFolder -Include *.jpg,*.jpeg,*.png,*.gif -Recurse
    foreach ($img in $Found) {
        $FileNameKey = $img.Name.ToLower()
        if (-not $SeenFiles.ContainsKey($FileNameKey)) {
            $SeenFiles[$FileNameKey] = $true
            $Photos += $img
        }
    }
} 
if ($Photos.Count -eq 0) { [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 找不到照片！請確認 images 資料夾內有圖片。", 48, "錯誤"); exit }

# 智慧分組
$GroupedProducts = @{}
foreach ($Photo in $Photos) {
    $ProductName = $Photo.BaseName -replace '[_\-\s0-9]+$', ''
    if ([string]::IsNullOrWhiteSpace($ProductName)) { $ProductName = $Photo.BaseName }
    if (-Not $GroupedProducts.ContainsKey($ProductName)) { $GroupedProducts[$ProductName] = @() }
    $GroupedProducts[$ProductName] += $Photo.FullName
}

# 🚀 核心修復：強制重構 CSV 欄位，解決舊資料擴充報錯 Bug
$ExistingItems = @()
$SeenCsvNames = @{}
if (Test-Path $CsvPath) {
    $RawItems = Import-Csv -Path $CsvPath -Encoding UTF8
    foreach ($Item in $RawItems) {
        if (-not $SeenCsvNames.ContainsKey($Item.name)) {
            $ExistingItems += [PSCustomObject]@{
                name       = $Item.name
                price      = $Item.price
                sale_price = if ($null -ne $Item.sale_price) { $Item.sale_price } else { "" }
                desc       = $Item.desc
                url        = if ($null -ne $Item.url) { $Item.url } else { "" }
                image      = if ($null -ne $Item.image) { $Item.image } else { "" }
            }
            $SeenCsvNames[$Item.name] = $true
        }
    }
}

# 建立 DNA 記憶字典 (極限無視大小寫配對)
$DnaMap = @{}
foreach ($Item in $ExistingItems) {
    $DnaMap[$Item.name.ToLower()] = $Item
    if (-not [string]::IsNullOrWhiteSpace($Item.image)) {
        $paths = $Item.image -split '\|'
        foreach ($p in $paths) {
            $fname = [System.IO.Path]::GetFileName($p -replace '/', '\').ToLower()
            if (-not [string]::IsNullOrWhiteSpace($fname)) { $DnaMap[$fname] = $Item }
        }
    }
}

# 專業版建檔介面 (查字典配對)
$NewItems = @()
$ProcessedNames = @{} 

foreach ($Key in $GroupedProducts.Keys) {
    $GroupedImages = $GroupedProducts[$Key]
    $GroupedFileNames = $GroupedImages | ForEach-Object { [System.IO.Path]::GetFileName($_).ToLower() }
    
    $MatchedItem = $null
    
    # 1. DNA 尋找
    foreach ($fname in $GroupedFileNames) {
        if ($DnaMap.ContainsKey($fname)) { $MatchedItem = $DnaMap[$fname]; break }
    }
    # 2. 舊名稱尋找
    if ($null -eq $MatchedItem -and $DnaMap.ContainsKey($Key.ToLower())) { $MatchedItem = $DnaMap[$Key.ToLower()] }
    
    if ($null -ne $MatchedItem) {
        if (-not $ProcessedNames.ContainsKey($MatchedItem.name)) {
            $MatchedItem.image = ($GroupedImages -join "|")
            $NewItems += $MatchedItem
            $ProcessedNames[$MatchedItem.name] = $true
        }
    } else {
        $formIn = New-Object System.Windows.Forms.Form
        $formIn.Text = "🆕 新商品建檔：$Key"; $formIn.Size = New-Object System.Drawing.Size(400, 550); $formIn.StartPosition = "CenterScreen"; $formIn.Font = New-Object System.Drawing.Font("微軟正黑體", 10)
        $startX = 20; $boxWidth = 340
        $addLbl = { param($t, $y) $l = New-Object System.Windows.Forms.Label; $l.Text=$t; $l.Location=New-Object System.Drawing.Point($startX, $y); $l.AutoSize=$true; $formIn.Controls.Add($l) }
        $addTxt = { param($v, $y, $h=30) $t = New-Object System.Windows.Forms.TextBox; $t.Text=$v; $t.Location=New-Object System.Drawing.Point($startX, ($y+22)); $t.Size=New-Object System.Drawing.Size($boxWidth, $h); if($h -gt 30){$t.Multiline=$true}; $formIn.Controls.Add($t); return $t }
        
        &$addLbl "商品名稱 (Name)" 10;   $tName = &$addTxt $Key 10
        &$addLbl "原價 (Price)" 75;      $tPrice = &$addTxt "100" 75
        &$addLbl "特價 (Sale Price - 選填)" 140; $tSale = &$addTxt "" 140
        &$addLbl "商品描述 (Description)" 205;   $tDesc = &$addTxt "全新/二手出清。" 205 80
        &$addLbl "參考網址 (URL - 選填)" 320;    $tUrl = &$addTxt "" 320
        
        $btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text="💾 儲存並繼續"; $btnSave.Location="120,420"; $btnSave.Size="150,45"; $btnSave.BackColor="LightBlue"; $btnSave.DialogResult="OK"
        $formIn.Controls.Add($btnSave); $formIn.AcceptButton = $btnSave
        if ($formIn.ShowDialog() -eq "OK") { 
            $newItem = [PSCustomObject]@{ name=$tName.Text; price=$tPrice.Text; sale_price=$tSale.Text; desc=$tDesc.Text; url=$tUrl.Text; image=($GroupedImages -join "|") }
            $NewItems += $newItem
            $ProcessedNames[$newItem.name] = $true
        } else { exit }
        $formIn.Dispose()
    }
}

# ⭐️ 庫存盤點
$formStock = New-Object System.Windows.Forms.Form
$formStock.Text = "📦 庫存狀況調整"; $formStock.Size = New-Object System.Drawing.Size(380, 500); $formStock.StartPosition = "CenterScreen"
$clb = New-Object System.Windows.Forms.CheckedListBox; $clb.Location="15,20"; $clb.Size="330,360"; $clb.CheckOnClick=$true
foreach ($Item in $NewItems) { [void]$clb.Items.Add($Item.name, ($Item.desc -match "\[售出\]")) }
$formStock.Controls.Add($clb)
$btnPub = New-Object System.Windows.Forms.Button; $btnPub.Text="🚀 開始發布"; $btnPub.Location="120,400"; $btnPub.Size="120,40"; $btnPub.DialogResult="OK"
$formStock.Controls.Add($btnPub)
if ($formStock.ShowDialog() -ne "OK") { exit }

for ($i=0; $i -lt $clb.Items.Count; $i++) {
    $target = $NewItems | Where-Object { $_.name -eq $clb.Items[$i] }
    if ($clb.GetItemChecked($i)) { if($target.desc -notmatch "\[售出\]"){$target.desc = "[售出] " + $target.desc} }
    else { $target.desc = $target.desc -replace "\[售出\]\s*", "" }
}

# 🛡️ 檔案寫入保護
try {
    $NewItems | Select-Object -Unique name, price, sale_price, desc, url, image | Export-Csv -Path $CsvPath -Encoding UTF8 -NoTypeInformation -Force -ErrorAction Stop
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 無法儲存！請先【關閉 Excel】後，再重新執行！", 48, "檔案被鎖死")
    exit
}

# ================= 網頁生成與壓縮 =================
$CacheBuster = (Get-Date).ToString("yyyyMMddHHmmss")
function Optimize-ImageToBase64 {
    param([string]$Path)
    try {
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
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache"><meta http-equiv="Expires" content="0">
    <title>$ShopTitle</title>
    <script>
        (function() {
            const currentVersion = '$CacheBuster';
            const savedVersion = localStorage.getItem('shop_version');
            if (savedVersion !== currentVersion) {
                localStorage.setItem('shop_version', currentVersion);
                const cleanUrl = window.location.origin + window.location.pathname + '?refresh=' + currentVersion;
                window.location.replace(cleanUrl);
            }
        })();
    </script>
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
    
    if (![string]::IsNullOrWhiteSpace($Item.sale_price)) {
        $PriceHtml = "<div class=`"price-container`"><span class=`"old-price`">NT$ $($Item.price)</span><span class=`"new-price`">🔥 NT$ $($Item.sale_price)</span></div>"
        $FinalPrice = $Item.sale_price
    } else {
        $PriceHtml = "<div class=`"price-container`"><span class=`"price`">NT$ $($Item.price)</span></div>"
        $FinalPrice = $Item.price
    }

    $UrlHtml = if (![string]::IsNullOrWhiteSpace($Item.url)) { "<a href=`"$($Item.url)`" target=`"_blank`" class=`"ref-link`">🔗 點此查看原廠參考網址</a>" } else { "" }

    $ImgPaths = $Item.image -split '\|'
    $Base64List = @(); $HighResList = @()
    foreach ($p in $ImgPaths) {
        $b = Optimize-ImageToBase64 -Path $p
        if ($b) { $Base64List += $b; $Rel = $p.Replace($ScriptPath, "").TrimStart("\").Replace("\", "/"); $HighResList += "$($SiteUrl)$($Rel)?v=$CacheBuster" }
    }
    if ($Base64List.Count -eq 0) { $Base64List += "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"; $HighResList += "" }

    $ThumbHtml = ""
    if ($Base64List.Count -gt 1) {
        $ThumbHtml = "<div class='thumb-container'>"
        for ($i=0; $i -lt $Base64List.Count; $i++) { $ThumbHtml += "<img src='$($Base64List[$i])' data-highres='$($HighResList[$i])' class='thumb-img' onclick='changeImg(this)'>" }
        $ThumbHtml += "</div>"
    }

    $BtnAction = if ($IsSold) { "alert('🚫 賣完囉！下次請早！')" } else { "copyInfo('$($Item.name)', '$FinalPrice', this)" }
    $BtnText = if ($IsSold) { "🚫 已售出" } else { "📋 複製購買資訊" }

    $CardsHtml += @"
    <div class="$CardClass" data-tags="$StatusTag $($Item.desc) $($Item.name)">
        <div class="main-img-container" onclick="openBox(this.querySelector('.main-img'))"><div class="sold-badge">已售出</div><img class="main-img" src="$($Base64List[0])" data-highres="$($HighResList[0])"></div>
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
        function changeImg(t){ 
            let m = t.closest('.card').querySelector('.main-img'); 
            m.src=t.src; 
            m.setAttribute('data-highres', t.getAttribute('data-highres')); 
        }
        function openBox(img){ 
            let box = document.getElementById('lightbox'); 
            let bImg = document.getElementById('box-img'); 
            let loader = document.getElementById('loading-text');
            let hr = img.getAttribute('data-highres');
            
            box.style.display='flex'; 
            bImg.style.display='none';
            
            if(hr){ 
                loader.style.display='block';
                let tmp = new Image(); 
                tmp.onload = () => { bImg.src=hr; loader.style.display='none'; bImg.style.display='block'; }; 
                tmp.onerror = () => { bImg.src=img.src; loader.style.display='none'; bImg.style.display='block'; };
                tmp.src=hr; 
            } else {
                bImg.src=img.src;
                bImg.style.display='block';
            }
        }
        function copyInfo(n, p, b){
            event.stopPropagation();
            navigator.clipboard.writeText('【我要購買】'+n+'\n金額：NT$ '+p).then(() => {
                let old = b.innerText; b.innerText = '✅ 已複製！'; b.style.background = '#27ae60';
                setTimeout(() => { b.innerText = old; b.style.background = '#3498db'; }, 2000);
            });
        }
        let activeFilters = new Set();
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const tag = this.dataset.tag;
                if (tag === 'all') { activeFilters.clear(); document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active')); this.classList.add('active'); }
                else { document.querySelector('[data-tag="all"]').classList.remove('active'); if (activeFilters.has(tag)) { activeFilters.delete(tag); this.classList.remove('active'); } else { activeFilters.add(tag); this.classList.add('active'); } }
                applyFilters();
            });
        });
        function applyFilters() {
            const search = document.getElementById('searchInput').value.toLowerCase();
            document.querySelectorAll('.card').forEach(card => {
                const tags = card.dataset.tags.toLowerCase();
                card.style.display = (tags.includes(search) && (activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.includes(f.toLowerCase())))) ? 'flex' : 'none';
            });
        }
        document.getElementById('searchInput').addEventListener('input', applyFilters);
    </script>
</body></html>
"@
[System.IO.File]::WriteAllText("$ScriptPath\index.html", ($HtmlStart + $CardsHtml + $HtmlEnd), [System.Text.Encoding]::UTF8)
$formStock.Dispose(); git add . ; git commit -m "V14-SchemaFix" ; git push origin main
[Microsoft.VisualBasic.Interaction]::MsgBox("🎉 最終抓蟲大成功！`n資料庫欄位已強制修復，無論你怎麼改商品名稱，系統都會死死鎖定照片 DNA！", 64, "大功告成")