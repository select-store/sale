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

# 🌟 社群分享 (LINE/FB) 預覽卡片設定
$ShopTitle = "📦 質感小物出清"
$ShopDesc  = "全新與二手好物特賣，點擊進來挖寶！"
$SiteUrl   = "https://select-store.github.io/sale/" 
# =========================================

if (-Not (Test-Path $ImageFolder)) { New-Item -ItemType Directory -Path $ImageFolder | Out-Null }
$Photos = Get-ChildItem -Path $ImageFolder -Include *.jpg,*.jpeg,*.png,*.gif -Recurse
if ($Photos.Count -eq 0) { [Microsoft.VisualBasic.Interaction]::MsgBox("❌ images 資料夾裡沒照片喔！", 48, "錯誤"); exit }

# 智慧分組照片
$GroupedProducts = @{}
foreach ($Photo in $Photos) {
    $ProductName = $Photo.BaseName -replace '[_\-\s0-9]+$', ''
    if ([string]::IsNullOrWhiteSpace($ProductName)) { $ProductName = $Photo.BaseName }
    if (-Not $GroupedProducts.ContainsKey($ProductName)) { $GroupedProducts[$ProductName] = @() }
    $GroupedProducts[$ProductName] += "images/$($Photo.Name)"
}

# 讀取舊資料
$ExistingData = @{}
if (Test-Path $CsvPath) {
    $OldItems = Import-Csv -Path $CsvPath -Encoding UTF8
    foreach ($Item in $OldItems) { $ExistingData[$Item.name] = $Item }
}

$NewItems = @()
foreach ($Key in $GroupedProducts.Keys) {
    $JoinedImages = $GroupedProducts[$Key] -join ", "
    if ($ExistingData.ContainsKey($Key)) {
        $Price = $ExistingData[$Key].price
        $Desc = $ExistingData[$Key].desc
        $Url = if ($null -ne $ExistingData[$Key].url) { $ExistingData[$Key].url } else { "" }
    } else {
        $Price = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的價格：", "新商品設定", "100")
        $Desc = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的商品描述：`n(若要特價請加上 [特價XXX])", "新商品設定", "全新/二手出清，歡迎詢問。")
        $Url = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的參考網址：`n(沒有請直接按確定留白)", "設定參考網址", "")
    }
    $NewItems += [PSCustomObject]@{ name = $Key; price = $Price; desc = $Desc; url = $Url; image = $JoinedImages }
}

# ⭐️ 庫存盤點系統 (彈出視窗)
$form = New-Object System.Windows.Forms.Form
$form.Text = "📦 出清庫存盤點後台"; $form.Size = New-Object System.Drawing.Size(380, 500); $form.StartPosition = "CenterScreen"; $form.Font = New-Object System.Drawing.Font("微軟正黑體", 11)
$label = New-Object System.Windows.Forms.Label; $label.Text = "請勾選已「售出」的商品："; $label.Location = New-Object System.Drawing.Point(15, 15); $label.AutoSize = $true; $form.Controls.Add($label)
$checkListBox = New-Object System.Windows.Forms.CheckedListBox; $checkListBox.Location = New-Object System.Drawing.Point(15, 45); $checkListBox.Size = New-Object System.Drawing.Size(330, 340); $checkListBox.CheckOnClick = $true
foreach ($Item in $NewItems) { [void]$checkListBox.Items.Add($Item.name, ($Item.desc -match "\[售出\]")) }
$form.Controls.Add($checkListBox)
$btnOK = New-Object System.Windows.Forms.Button; $btnOK.Location = New-Object System.Drawing.Point(120, 400); $btnOK.Size = New-Object System.Drawing.Size(120, 40); $btnOK.Text = "💾 儲存並發布"; $btnOK.BackColor = [System.Drawing.Color]::LightGreen; $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $btnOK; $form.Controls.Add($btnOK)
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    for ($i = 0; $i -lt $checkListBox.Items.Count; $i++) {
        $itemName = $checkListBox.Items[$i]; $isChecked = $checkListBox.GetItemChecked($i)
        $targetItem = $NewItems | Where-Object { $_.name -eq $itemName }
        if ($isChecked) { if ($targetItem.desc -notmatch "\[售出\]") { $targetItem.desc = "[售出] " + $targetItem.desc } }
        else { $targetItem.desc = $targetItem.desc -replace "\[售出\]\s*", "" }
    }
} else { exit }
$NewItems | Export-Csv -Path $CsvPath -Encoding UTF8 -NoTypeInformation

# ⭐️ 擷取第一張圖片做為社群預覽圖 (OG Image)
$OgImageUrl = ""
if ($NewItems.Count -gt 0) {
    $FirstImagePath = ($NewItems[0].image -split ',')[0].Trim() -replace '\\', '/'
    $OgImageUrl = $SiteUrl + $FirstImagePath
}

$HtmlStart = @"
<!DOCTYPE html>
<html lang="zh-TW"><head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ShopTitle</title>
    <script>
        let u = new URL(window.location.href);
        if (!u.searchParams.has('v')) {
            u.searchParams.set('v', new Date().getTime());
            window.location.replace(u.toString());
        } else {
            u.searchParams.delete('v');
            window.history.replaceState(null, '', u.toString());
        }
    </script>
    <meta property="og:title" content="$ShopTitle">
    <meta property="og:description" content="$ShopDesc">
    <meta property="og:image" content="$OgImageUrl">
    <meta property="og:url" content="$SiteUrl">
    <meta property="og:type" content="website">
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #f8f9fa; margin: 0; padding: 15px; overflow-x: hidden; transition: background 0.3s; }
        .search-container { width: 100%; max-width: 800px; margin: 0 auto 10px auto; }
        #searchInput { width: 100%; padding: 14px 20px; border: 2px solid #e0e0e0; border-radius: 30px; font-size: 1rem; outline: none; transition: all 0.3s; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
        #searchInput:focus { border-color: #3498db; box-shadow: 0 4px 12px rgba(52, 152, 219, 0.2); }
        
        /* 標籤與排序按鈕 */
        .filter-container { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; max-width: 800px; margin: 0 auto 20px auto; }
        .filter-btn { background: #e0e0e0; border: none; padding: 6px 14px; border-radius: 20px; cursor: pointer; font-size: 0.9rem; color: #333; transition: all 0.2s; }
        .filter-btn:hover, .filter-btn.active { background: #3498db; color: white; }
        .sort-btn { background: #f39c12; color: white; border: none; padding: 6px 14px; border-radius: 20px; cursor: pointer; font-size: 0.9rem; transition: all 0.2s; font-weight: bold; }
        .sort-btn:hover { background: #e67e22; }

        .grid-container { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; width: 100%; max-width: 1400px; margin: 0 auto; }
        @media (min-width: 768px) { .grid-container { grid-template-columns: repeat(4, 1fr); gap: 15px; } }
        @media (min-width: 1200px) { .grid-container { grid-template-columns: repeat(6, 1fr); gap: 18px; } }
        .card { background: #fff; border-radius: 12px; padding: 12px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); display: flex; flex-direction: column; position: relative; transition: transform 0.2s, background 0.3s; }
        .card:hover { transform: translateY(-3px); box-shadow: 0 6px 15px rgba(0,0,0,0.1); }
        .main-img-container { width: 100%; height: 0; padding-bottom: 100%; position: relative; border-radius: 8px; overflow: hidden; margin-bottom: 10px; background: #fff; }
        .main-img { position: absolute; top: 0; left: 0; width: 100%; height: 100%; object-fit: contain; cursor: zoom-in; }
        
        .sold-badge { display: none; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-15deg); background: rgba(231, 76, 60, 0.95); color: white; padding: 8px 18px; font-weight: bold; border-radius: 6px; z-index: 10; border: 3px solid white; box-shadow: 0 4px 10px rgba(0,0,0,0.3); letter-spacing: 2px; }
        .sold-out .main-img, .sold-out .thumbnails { filter: grayscale(100%); opacity: 0.5; }
        .sold-out .sold-badge { display: block; }
        
        .thumbnails { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 6px; }
        .thumbnails img { width: 40px; height: 40px; object-fit: contain; border-radius: 6px; cursor: pointer; border: 2px solid transparent; background: #fff; }
        .card h3 { margin: 0 0 6px 0; font-size: 1.05rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #2c3e50; }
        
        /* 價格特價顯示 */
        .price-container { margin-bottom: 8px; }
        .price { color: #e74c3c; font-weight: bold; font-size: 1.15rem; }
        .old-price { color: #999; text-decoration: line-through; font-size: 0.9rem; margin-right: 8px; }
        .new-price { color: #e74c3c; font-weight: bold; font-size: 1.2rem; background: #ffebee; padding: 2px 6px; border-radius: 4px; }
        
        .desc { font-size: 0.85rem; color: #666; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; margin-bottom: 6px; line-height: 1.4; }
        .ref-link { font-size: 0.85rem; color: #3498db; text-decoration: none; font-weight: bold; margin-bottom: 12px; display: inline-block; flex-grow: 1; }
        .ref-link:hover { color: #2980b9; text-decoration: underline; }
        .no-link { flex-grow: 1; margin-bottom: 12px; }
        .btn-copy { background: #3498db; color: white; border: none; padding: 8px; border-radius: 6px; cursor: pointer; font-size: 0.9rem; font-weight: bold; transition: background 0.2s; }
        .btn-copy:hover { background: #2980b9; }
        .floating-line { position: fixed; bottom: 30px; right: 30px; background: #06C755; color: white; padding: 14px 24px; border-radius: 50px; text-decoration: none; font-weight: bold; box-shadow: 0 4px 12px rgba(0,0,0,0.25); z-index: 100; transition: transform 0.2s; }
        .floating-line:hover { transform: scale(1.05); }
        #lightbox { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); z-index: 999; justify-content: center; align-items: center; }
        #lightbox img { max-width: 90%; max-height: 90%; border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
        #toast { visibility: hidden; min-width: 250px; background-color: #333; color: #fff; text-align: center; border-radius: 30px; padding: 14px; position: fixed; z-index: 1000; left: 50%; bottom: 20px; transform: translateX(-50%); font-size: 1rem; box-shadow: 0px 5px 15px rgba(0,0,0,0.3); opacity: 0; transition: opacity 0.3s, bottom 0.3s; font-weight: bold; }
        #toast.show { visibility: visible; opacity: 1; bottom: 50px; }

        @media (prefers-color-scheme: dark) {
            body { background: #121212; }
            #searchInput { background: #1e1e1e; color: #fff; border-color: #333; box-shadow: 0 4px 6px rgba(0,0,0,0.2); }
            .filter-btn { background: #333; color: #ccc; }
            .card { background: #1e1e1e; box-shadow: 0 4px 10px rgba(0,0,0,0.4); }
            .main-img-container, .thumbnails img { background: #2c2c2c; }
            .card h3 { color: #e0e0e0; }
            .desc { color: #aaa; }
            .new-price { background: #4a0000; }
            .sold-badge { border-color: #1e1e1e; }
            #toast { background-color: #e0e0e0; color: #121212; }
        }
    </style>
</head><body>
    <div class="search-container">
        <input type="text" id="searchInput" placeholder="🔍 輸入關鍵字搜尋商品或描述...">
    </div>
    <div class="filter-container">
        <button class="filter-btn active" onclick="filterTag('')">全部</button>
        <button class="filter-btn" onclick="filterTag('3c')">#3C</button>
        <button class="filter-btn" onclick="filterTag('二手')">#二手</button>
        <button class="filter-btn" onclick="filterTag('全新')">#全新</button>
        <button class="sort-btn" onclick="sortCards(true)">⬆️ 便宜優先</button>
        <button class="sort-btn" onclick="sortCards(false)">⬇️ 高價優先</button>
    </div>
    <div class="grid-container" id="productGrid">
"@

$CardsHtml = ""
foreach ($Item in $NewItems) {
    # 判斷是否售出
    $IsSold = ($Item.desc -match "\[售出\]")
    $CardClass = if ($IsSold) { "card sold-out" } else { "card" }
    
    # 價格與 FOMO 特價邏輯
    $OriginalPrice = $Item.price
    $DisplayDesc = $Item.desc
    $SalePrice = ""
    $ActualSortPrice = $OriginalPrice
    
    if ($DisplayDesc -match "\[特價(\d+)\]") {
        $SalePrice = $matches[1]
        $ActualSortPrice = $SalePrice
        $DisplayDesc = $DisplayDesc -replace "\[特價\d+\]\s*", ""
        $PriceHtml = "<div class=`"price-container`"><span class=`"old-price`">NT$ $OriginalPrice</span><span class=`"new-price`">🔥 NT$ $SalePrice</span></div>"
        $BtnPrice = $SalePrice
    } else {
        $PriceHtml = "<div class=`"price-container`"><span class=`"price`">NT$ $OriginalPrice</span></div>"
        $BtnPrice = $OriginalPrice
    }

    $BtnText = if ($IsSold) { "🚫 已售出" } else { "📋 複製購買資訊" }
    $BtnAction = if ($IsSold) { "showToast('🚫 賣完囉！下次請早！');" } else { "copyInfo('【我要購買】$($Item.name)\n金額：NT$ $BtnPrice', this)" }
    
    if (-not [string]::IsNullOrWhiteSpace($Item.url)) {
        $UrlHtml = "<a href=`"$($Item.url)`" target=`"_blank`" class=`"ref-link`">🔗 參考網址</a>"
    } else {
        $UrlHtml = "<div class=`"no-link`"></div>"
    }

    # 解除 Base64，直接讀取檔案路徑
    $ImagesPaths = $Item.image -split ',' | ForEach-Object { $_.Trim() -replace '\\', '/' }
    $MainImage = if ($ImagesPaths.Count -gt 0) { $ImagesPaths[0] } else { "" }
    
    $Thumbs = ""
    if ($ImagesPaths.Count -gt 1) { 
        $Thumbs += '<div class="thumbnails">'
        foreach ($img in $ImagesPaths) { $Thumbs += "<img src=`"$img`" loading=`"lazy`" onclick=`"changeMainImg(this, '$img')`">" }
        $Thumbs += '</div>' 
    }
    
    # 加入 data-price 供排序使用
    $CardsHtml += @"
    <div class="$CardClass" data-price="$ActualSortPrice"><div class="main-img-container"><div class="sold-badge">已售出</div><img class="main-img" src="$MainImage" loading="lazy" onclick="openLightbox(this.src)"></div>
    $Thumbs<h3>$($Item.name)</h3>$PriceHtml<p class="desc" title="$DisplayDesc">$DisplayDesc</p>
    $UrlHtml
    <button class="btn-copy" onclick="$BtnAction">$BtnText</button></div>
"@
}

$HtmlEnd = @"
    </div>
    <a href="$LineLink" class="floating-line" target="_blank">💬 聯繫我 (LINE)</a>
    <div id="lightbox" onclick="closeLightbox()"><img id="lightbox-img"></div>
    <div id="toast"></div>

    <script>
        function changeMainImg(t, s) { t.closest('.card').querySelector('.main-img').src = s; }
        function openLightbox(s) { document.getElementById('lightbox-img').src = s; document.getElementById('lightbox').style.display = 'flex'; }
        function closeLightbox() { document.getElementById('lightbox').style.display = 'none'; }
        
        function showToast(msg) {
            let x = document.getElementById("toast");
            x.innerText = msg; x.className = "show";
            setTimeout(function(){ x.className = x.className.replace("show", ""); }, 2500);
        }

        function copyInfo(t, b) { 
            navigator.clipboard.writeText(t).then(() => { 
                let o = b.innerText; b.innerText = '✅ 已複製！'; b.style.background = '#27ae60'; 
                showToast('✅ 聯絡資訊已複製！');
                setTimeout(() => { b.innerText = o; b.style.background = '#3498db'; }, 2500); 
            }); 
        }

        // 搜尋功能
        document.getElementById('searchInput').addEventListener('keyup', function() {
            let filter = this.value.toLowerCase();
            document.querySelectorAll('.card').forEach(card => {
                let text = card.innerText.toLowerCase();
                card.style.display = text.includes(filter) ? 'flex' : 'none';
            });
        });

        // 標籤過濾功能
        function filterTag(tag) {
            document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
            event.target.classList.add('active');
            let filter = tag.toLowerCase();
            document.querySelectorAll('.card').forEach(card => {
                let text = card.innerText.toLowerCase();
                card.style.display = text.includes(filter) ? 'flex' : 'none';
            });
        }

        // 價格排序功能
        let sortAsc = true;
        function sortCards(asc) {
            let grid = document.getElementById('productGrid');
            let cards = Array.from(grid.getElementsByClassName('card'));
            cards.sort((a, b) => {
                let priceA = parseInt(a.getAttribute('data-price')) || 0;
                let priceB = parseInt(b.getAttribute('data-price')) || 0;
                return asc ? priceA - priceB : priceB - priceA;
            });
            grid.innerHTML = '';
            cards.forEach(card => grid.appendChild(card));
        }
    </script>
</body></html>
"@
[System.IO.File]::WriteAllText("$ScriptPath\index.html", ($HtmlStart + $CardsHtml + $HtmlEnd), [System.Text.Encoding]::UTF8)

$form.Dispose()

try {
    Write-Host "🚀 啟動終極發射程序：正在將最新庫存同步至 GitHub 伺服器..." -ForegroundColor Cyan
    git add .
    $commitMsg = "📦 庫存更新: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    git commit -m $commitMsg | Out-Null
    git pull origin main --no-edit | Out-Null
    git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 完美！系統升級完畢且全自動更新至雲端！", 64, "大功告成")
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 自動推播失敗。請確認網路連線。", 48, "系統錯誤")
}