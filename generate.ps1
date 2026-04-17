# 強制鎖定當前資料夾
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }
Set-Location -Path $ScriptPath

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# ================= 設定區 =================
$LineLink = "https://lin.ee/7NldLO6"
$ImageFolders = @(".\images", ".\images_已售出")
$CsvPath = ".\items.csv"
$ShopTitle = "📦 小物出清"
$ShopDesc  = "全新與二手好物特賣，點擊進來挖寶！"
$SiteUrl   = "https://select-store.github.io/sale/" 
# =========================================

# 掃描所有照片
$Photos = @()
foreach ($folder in $ImageFolders) {
    if (Test-Path $folder) {
        $Photos += Get-ChildItem -Path $folder -Include *.jpg,*.jpeg,*.png,*.gif -Recurse
    }
}

if ($Photos.Count -eq 0) { [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 找不到任何照片！", 48, "錯誤"); exit }

# 智慧分組照片
$GroupedProducts = @{}
foreach ($Photo in $Photos) {
    $ProductName = $Photo.BaseName -replace '[_\-\s0-9]+$', ''
    if ([string]::IsNullOrWhiteSpace($ProductName)) { $ProductName = $Photo.BaseName }
    if (-Not $GroupedProducts.ContainsKey($ProductName)) { $GroupedProducts[$ProductName] = @() }
    $GroupedProducts[$ProductName] += $Photo.FullName
}

# 讀取舊資料
$ExistingData = @{}
if (Test-Path $CsvPath) {
    $OldItems = Import-Csv -Path $CsvPath -Encoding UTF8
    foreach ($Item in $OldItems) { $ExistingData[$Item.name] = $Item }
}

$NewItems = @()
foreach ($Key in $GroupedProducts.Keys) {
    $JoinedImages = $GroupedProducts[$Key] -join "|"
    if ($ExistingData.ContainsKey($Key)) {
        $Price = $ExistingData[$Key].price
        $Desc = $ExistingData[$Key].desc
        $Url = $ExistingData[$Key].url
    } else {
        $Price = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的價格：", "新商品設定", "100")
        $Desc = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的商品描述：", "新商品設定", "全新/二手出清。")
        $Url = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的參考網址：", "設定參考網址", "")
    }
    $NewItems += [PSCustomObject]@{ name = $Key; price = $Price; desc = $Desc; url = $Url; image = $JoinedImages }
}

# ⭐️ 庫存盤點視窗
$form = New-Object System.Windows.Forms.Form
$form.Text = "📦 出清庫存盤點後台"; $form.Size = New-Object System.Drawing.Size(380, 500); $form.StartPosition = "CenterScreen"; $form.Font = New-Object System.Drawing.Font("微軟正黑體", 11)
$checkListBox = New-Object System.Windows.Forms.CheckedListBox; $checkListBox.Location = New-Object System.Drawing.Point(15, 45); $checkListBox.Size = New-Object System.Drawing.Size(330, 340); $checkListBox.CheckOnClick = $true
foreach ($Item in $NewItems) { [void]$checkListBox.Items.Add($Item.name, ($Item.desc -match "\[售出\]")) }
$form.Controls.Add($checkListBox)
$btnOK = New-Object System.Windows.Forms.Button; $btnOK.Location = New-Object System.Drawing.Point(120, 400); $btnOK.Size = New-Object System.Drawing.Size(120, 40); $btnOK.Text = "💾 儲存並發布"; $btnOK.BackColor = [System.Drawing.Color]::LightGreen; $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnOK)
if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }

for ($i = 0; $i -lt $checkListBox.Items.Count; $i++) {
    $itemName = $checkListBox.Items[$i]; $isChecked = $checkListBox.GetItemChecked($i)
    $targetItem = $NewItems | Where-Object { $_.name -eq $itemName }
    if ($isChecked) { if ($targetItem.desc -notmatch "\[售出\]") { $targetItem.desc = "[售出] " + $targetItem.desc } }
    else { $targetItem.desc = $targetItem.desc -replace "\[售出\]\s*", "" }
}
$NewItems | Export-Csv -Path $CsvPath -Encoding UTF8 -NoTypeInformation

# ================= 核心黑科技 =================
$CacheBuster = (Get-Date).ToString("MMddHHmmss")

function Optimize-ImageToBase64 {
    param([string]$Path)
    try {
        if (-Not (Test-Path $Path)) { return $null }
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
    <title>$ShopTitle</title>
    <script>
        // 🚀 網頁本體快取殺手
        let u = new URL(window.location.href);
        if (!u.searchParams.has('v')) {
            u.searchParams.set('v', '$CacheBuster');
            window.location.replace(u.toString());
        }
    </script>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #121212; color: #eee; margin: 0; padding: 0; overflow-x: hidden; }
        .search-container { padding: 10px; background: #1e1e1e; position: sticky; top: 0; z-index: 100; border-bottom: 1px solid #333; }
        #searchInput { width: 100%; max-width: 800px; margin: 0 auto; display: block; padding: 12px 20px; border: 1px solid #444; border-radius: 25px; background: #222; color: #fff; outline: none; box-sizing: border-box; }
        .filter-container { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; padding: 15px 10px; }
        .filter-btn { background: #333; border: none; padding: 8px 16px; border-radius: 20px; cursor: pointer; color: #ccc; font-size: 0.9rem; }
        .filter-btn.active { background: #3498db; color: white; }
        
        .grid-container { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; padding: 12px; max-width: 1600px; margin: 0 auto; }
        @media (min-width: 768px) { .grid-container { grid-template-columns: repeat(4, 1fr); gap: 15px; } }
        @media (min-width: 1200px) { .grid-container { grid-template-columns: repeat(6, 1fr); gap: 18px; } }
        
        .card { background: #1e1e1e; display: flex; flex-direction: column; position: relative; padding: 12px; border-radius: 12px; border: 1px solid #333; transition: transform 0.2s; }
        .main-img-container { width: 100%; aspect-ratio: 1/1; position: relative; overflow: hidden; background: #2c2c2c; border-radius: 8px; cursor: zoom-in; margin-bottom: 8px; }
        .main-img { width: 100%; height: 100%; object-fit: contain; }
        .sold-badge { display: none; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-15deg); background: rgba(231, 76, 60, 0.95); color: white; padding: 6px 16px; font-weight: bold; border-radius: 6px; z-index: 10; border: 2px solid white; pointer-events: none; }
        .sold-out .sold-badge { display: block; }
        .sold-out .main-img { filter: grayscale(100%); opacity: 0.4; }
        
        .thumb-container { display: flex; gap: 4px; padding: 4px 0; overflow-x: auto; margin-bottom: 10px; }
        .thumb-img { width: 38px; height: 38px; object-fit: cover; border-radius: 4px; cursor: pointer; opacity: 0.5; border: 1px solid transparent; }
        .thumb-img:hover { opacity: 1; border-color: #3498db; }

        .info { flex-grow: 1; display: flex; flex-direction: column; margin-bottom: 12px; }
        h3 { margin: 0 0 8px 0; font-size: 1rem; color: #fff; }
        .price-container { margin-bottom: 8px; }
        .price { color: #e74c3c; font-weight: bold; font-size: 1.15rem; }
        .old-price { color: #777; text-decoration: line-through; font-size: 0.9rem; margin-right: 6px; }
        .new-price { color: #e74c3c; font-weight: bold; background: rgba(231, 76, 60, 0.15); padding: 2px 6px; border-radius: 4px; }
        .desc { font-size: 0.85rem; color: #aaa; margin: 0 0 10px 0; line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
        .ref-link { font-size: 0.85rem; color: #3498db; text-decoration: none; font-weight: bold; align-self: flex-start; }

        .btn-copy { background: #3498db; color: white; border: none; padding: 10px; border-radius: 8px; cursor: pointer; font-weight: bold; font-size: 0.9rem; width: 100%; }
        .btn-copy:hover { background: #2980b9; }

        .floating-line { position: fixed; bottom: 30px; right: 30px; background: #06C755; color: white; padding: 14px 24px; border-radius: 50px; text-decoration: none; font-weight: bold; box-shadow: 0 4px 12px rgba(0,0,0,0.3); z-index: 100; transition: transform 0.2s; }
        .floating-line:hover { transform: scale(1.05); }

        #lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); z-index: 999; justify-content: center; align-items: center; }
        #lightbox img { max-width: 95%; max-height: 95%; border-radius: 4px; object-fit: contain; }
        #loading-text { position: absolute; color: #fff; font-weight: bold; display: none; }
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
    
    $OriginalPrice = $Item.price
    $DisplayDesc = $Item.desc
    if ($DisplayDesc -match "\[特價(\d+)\]") {
        $SalePrice = $matches[1]
        $DisplayDesc = $DisplayDesc -replace "\[特價\d+\]\s*", ""
        $PriceHtml = "<div class=`"price-container`"><span class=`"old-price`">NT$ $OriginalPrice</span><span class=`"new-price`">🔥 NT$ $SalePrice</span></div>"
        $BtnPrice = $SalePrice
    } else {
        $PriceHtml = "<div class=`"price-container`"><span class=`"price`">NT$ $OriginalPrice</span></div>"
        $BtnPrice = $OriginalPrice
    }

    $UrlHtml = if (-not [string]::IsNullOrWhiteSpace($Item.url)) { "<a href=`"$($Item.url)`" target=`"_blank`" class=`"ref-link`">🔗 參考網址</a>" } else { "" }

    $ImgPaths = $Item.image -split '\|'
    $Base64List = @(); $HighResList = @()
    foreach ($p in $ImgPaths) {
        $b64 = Optimize-ImageToBase64 -Path $p
        if ($b64) { 
            $Base64List += $b64
            # 修正 URL 路徑邏輯：確保路徑編碼正確且指向 GitHub 倉庫
            $RelativePath = $p.Replace($ScriptPath, "").TrimStart("\").Replace("\", "/")
            $HighResList += "$($SiteUrl)$($RelativePath)?v=$CacheBuster"
        }
    }
    if ($Base64List.Count -eq 0) { $Base64List += "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"; $HighResList += "" }

    $ThumbHtml = ""
    if ($Base64List.Count -gt 1) {
        $ThumbHtml = "<div class='thumb-container'>"
        for ($i=0; $i -lt $Base64List.Count; $i++) {
            $ThumbHtml += "<img src='$($Base64List[$i])' data-highres='$($HighResList[$i])' class='thumb-img' onclick='changeMainImg(this)'>"
        }
        $ThumbHtml += "</div>"
    }

    $BtnAction = if ($IsSold) { "showSoldToast()" } else { "copyInfo('$($Item.name)', '$BtnPrice', this)" }
    $BtnText = if ($IsSold) { "🚫 已售出" } else { "📋 複製購買資訊" }

    $CardsHtml += @"
    <div class="$CardClass" data-tags="$StatusTag $($Item.desc) $($Item.name)">
        <div class="main-img-container" onclick="openLightbox(this.querySelector('.main-img'))">
            <div class="sold-badge">已售出</div>
            <img class="main-img" src="$($Base64List[0])" data-highres="$($HighResList[0])">
        </div>
        $ThumbHtml
        <div class="info">
            <h3>$($Item.name)</h3>
            $PriceHtml
            <p class="desc">$DisplayDesc</p>
            $UrlHtml
        </div>
        <button class="btn-copy" onclick="$BtnAction">$BtnText</button>
    </div>
"@
}

$HtmlEnd = @"
    </div>
    <a href="$LineLink" class="floating-line" target="_blank">💬 聯繫我 (LINE)</a>
    <div id="lightbox" onclick="closeLightbox()"><span id="loading-text">載入高清圖中...</span><img id="lightbox-img"></div>
    <script>
        function changeMainImg(thumb) {
            let container = thumb.closest('.card').querySelector('.main-img');
            container.src = thumb.src;
            container.setAttribute('data-highres', thumb.getAttribute('data-highres'));
        }
        function openLightbox(img) {
            let box = document.getElementById('lightbox');
            let boxImg = document.getElementById('lightbox-img');
            let loader = document.getElementById('loading-text');
            let highRes = img.getAttribute('data-highres');
            box.style.display = 'flex';
            boxImg.style.display = 'none';
            if(highRes) {
                loader.style.display = 'block';
                let temp = new Image();
                temp.onload = () => { boxImg.src = highRes; loader.style.display = 'none'; boxImg.style.display = 'block'; };
                temp.onerror = () => { boxImg.src = img.src; loader.style.display = 'none'; boxImg.style.display = 'block'; };
                temp.src = highRes;
            } else { boxImg.src = img.src; boxImg.style.display = 'block'; }
        }
        function closeLightbox() { document.getElementById('lightbox').style.display = 'none'; }
        function showSoldToast() { alert('🚫 賣完囉！下次請早！'); }
        function copyInfo(name, price, btn) {
            navigator.clipboard.writeText('【我要購買】' + name + '\n金額：NT$ ' + price).then(() => {
                let old = btn.innerText; btn.innerText = '✅ 已複製！'; btn.style.background = '#27ae60';
                setTimeout(() => { btn.innerText = old; btn.style.background = '#3498db'; }, 2000);
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
                const mSearch = tags.includes(search);
                const mTags = activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.includes(f.toLowerCase()));
                card.style.display = (mSearch && mTags) ? 'flex' : 'none';
            });
        }
        document.getElementById('searchInput').addEventListener('input', applyFilters);
    </script>
</body></html>
"@
[System.IO.File]::WriteAllText("$ScriptPath\index.html", ($HtmlStart + $CardsHtml + $HtmlEnd), [System.Text.Encoding]::UTF8)
$form.Dispose()

# 自動推播
try {
    Write-Host "🚀 正在將 V8 終極版發射至 GitHub..." -ForegroundColor Cyan
    git add . ; git commit -m "V8-Final-Fix" ; git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 V8 終極版部署成功！`n1. 高清圖抓取邏輯已修正`n2. 已售出商品現在會顯示提示`n3. 強制更新機制已鎖定", 64, "大功告成")
} catch { [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 發射失敗，請檢查網路。", 48, "錯誤") }