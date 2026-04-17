# 強制鎖定當前資料夾
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }
Set-Location -Path $ScriptPath

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# ================= 設定區 =================
$LineLink = "https://lin.ee/7NldLO6"
$ImageFolders = @(".\images", ".\images_已售出") # 同時讀取兩個資料夾
$CsvPath = ".\items.csv"
$ShopTitle = "📦 質感小物出清"
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
    # 這裡的邏輯：把檔案名稱最後的數字或底線去掉作為商品名
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
    # 儲存完整路徑，方便後面轉 Base64
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

# 極限壓縮 (A方案 300px)
function Optimize-ImageToBase64 {
    param([string]$Path)
    try {
        if (-Not (Test-Path $Path)) { return $null }
        $bmp = [System.Drawing.Image]::FromFile($Path); $maxWidth = 300; $width = $bmp.Width; $height = $bmp.Height
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
        body { font-family: 'Segoe UI', sans-serif; background: #121212; color: #eee; margin: 0; padding: 0; overflow-x: hidden; }
        .search-container { padding: 10px; background: #1e1e1e; position: sticky; top: 0; z-index: 100; }
        #searchInput { width: 100%; padding: 12px; border: 1px solid #444; border-radius: 25px; background: #222; color: #fff; outline: none; box-sizing: border-box; }
        .filter-container { display: flex; flex-wrap: wrap; gap: 5px; justify-content: center; padding: 10px; background: #1e1e1e; }
        .filter-btn { background: #333; border: none; padding: 6px 12px; border-radius: 15px; cursor: pointer; color: #ccc; font-size: 0.85rem; }
        .filter-btn.active { background: #3498db; color: white; }
        
        /* 滿版 7 欄位排版 */
        .grid-container { display: grid; grid-template-columns: repeat(2, 1fr); gap: 2px; background: #000; }
        @media (min-width: 768px) { .grid-container { grid-template-columns: repeat(4, 1fr); } }
        @media (min-width: 1200px) { .grid-container { grid-template-columns: repeat(7, 1fr); } }
        
        .card { background: #1e1e1e; display: flex; flex-direction: column; position: relative; padding-bottom: 10px; border: 0.5px solid #333; }
        .main-img-container { width: 100%; aspect-ratio: 1/1; position: relative; overflow: hidden; background: #2c2c2c; }
        .main-img { width: 100%; height: 100%; object-fit: contain; }
        .sold-badge { display: none; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-15deg); background: rgba(231, 76, 60, 0.9); color: white; padding: 4px 10px; font-weight: bold; border-radius: 4px; z-index: 10; border: 2px solid white; font-size: 0.8rem; pointer-events: none; }
        .sold-out .sold-badge { display: block; }
        .sold-out .main-img { filter: grayscale(100%); opacity: 0.4; }
        
        /* 多圖縮圖區 */
        .thumb-container { display: flex; gap: 2px; padding: 4px; overflow-x: auto; background: #121212; }
        .thumb-img { width: 30px; height: 30px; object-fit: cover; border-radius: 2px; cursor: pointer; opacity: 0.6; }
        .thumb-img:hover { opacity: 1; }

        .info { padding: 8px; flex-grow: 1; }
        h3 { margin: 0; font-size: 0.9rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .price { color: #e74c3c; font-weight: bold; font-size: 1rem; margin: 4px 0; }
        .btn-copy { background: #3498db; color: white; border: none; padding: 8px; border-radius: 4px; cursor: pointer; font-weight: bold; font-size: 0.8rem; width: calc(100% - 16px); margin: 0 auto; }
    </style>
</head><body>
    <div class="search-container"><input type="text" id="searchInput" placeholder="🔍 搜尋商品..."></div>
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
    
    # 處理多張圖片
    $ImgPaths = $Item.image -split '\|'
    $Base64List = @()
    foreach ($p in $ImgPaths) {
        $b64 = Optimize-ImageToBase64 -Path $p
        if ($b64) { $Base64List += $b64 }
    }
    
    if ($Base64List.Count -eq 0) { $Base64List += "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" }
    $MainImg = $Base64List[0]
    
    # 縮圖 HTML
    $ThumbHtml = ""
    if ($Base64List.Count -gt 1) {
        $ThumbHtml = "<div class='thumb-container'>"
        foreach ($b in $Base64List) { $ThumbHtml += "<img src='$b' class='thumb-img' onclick='this.closest(`".card`").querySelector(`".main-img`").src=this.src'> " }
        $ThumbHtml += "</div>"
    }

    $CardsHtml += @"
    <div class="$CardClass" data-tags="$StatusTag $($Item.desc) $($Item.name)">
        <div class="main-img-container"><div class="sold-badge">已售出</div><img class="main-img" src="$MainImg"></div>
        $ThumbHtml
        <div class="info"><h3>$($Item.name)</h3><p class="price">NT$ $($Item.price)</p></div>
        <button class="btn-copy" onclick="copyInfo('$($Item.name)', '$($Item.price)')">📋 複製購買資訊</button>
    </div>
"@
}

$HtmlEnd = @"
    </div>
    <script>
        function copyInfo(name, price) {
            const text = '【我要購買】' + name + '\n金額：NT$ ' + price;
            navigator.clipboard.writeText(text).then(() => alert('✅ 已複製購買資訊！'));
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
git add . ; git commit -m "V5-Full" ; git push origin main
[Microsoft.VisualBasic.Interaction]::MsgBox("🎉 滿版 7 欄位 + 多圖支援升級完成！", 64, "大功告成")