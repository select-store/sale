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
$ShopTitle = "📦 小物出清"
$ShopDesc  = "全新與二手好物特賣，點擊進來挖寶！"
$SiteUrl   = "https://select-store.github.io/sale/" 
# =========================================

# 自動建立資料夾
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
        $Desc = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的商品描述：`n(特價請加 [特價XXX])", "新商品設定", "全新/二手出清。")
        $Url = [Microsoft.VisualBasic.Interaction]::InputBox("👉 請輸入【$Key】的參考網址：", "設定參考網址", "")
    }
    $NewItems += [PSCustomObject]@{ name = $Key; price = $Price; desc = $Desc; url = $Url; image = $JoinedImages }
}

# ⭐️ 庫存盤點系統
$form = New-Object System.Windows.Forms.Form
$form.Text = "📦 出清庫存盤點後台"; $form.Size = New-Object System.Drawing.Size(380, 500); $form.StartPosition = "CenterScreen"; $form.Font = New-Object System.Drawing.Font("微軟正黑體", 11)
$checkListBox = New-Object System.Windows.Forms.CheckedListBox; $checkListBox.Location = New-Object System.Drawing.Point(15, 45); $checkListBox.Size = New-Object System.Drawing.Size(330, 340); $checkListBox.CheckOnClick = $true
foreach ($Item in $NewItems) { [void]$checkListBox.Items.Add($Item.name, ($Item.desc -match "\[售出\]")) }
$form.Controls.Add($checkListBox)
$btnOK = New-Object System.Windows.Forms.Button; $btnOK.Location = New-Object System.Drawing.Point(120, 400); $btnOK.Size = New-Object System.Drawing.Size(120, 40); $btnOK.Text = "💾 儲存並發布"; $btnOK.BackColor = [System.Drawing.Color]::LightGreen; $btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($btnOK)
$result = $form.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    for ($i = 0; $i -lt $checkListBox.Items.Count; $i++) {
        $itemName = $checkListBox.Items[$i]; $isChecked = $checkListBox.GetItemChecked($i)
        $targetItem = $NewItems | Where-Object { $_.name -eq $itemName }
        if ($isChecked) { 
            if ($targetItem.desc -notmatch "\[售出\]") { $targetItem.desc = "[售出] " + $targetItem.desc }
        } else { 
            $targetItem.desc = $targetItem.desc -replace "\[售出\]\s*", "" 
        }
    }
} else { exit }
$NewItems | Export-Csv -Path $CsvPath -Encoding UTF8 -NoTypeInformation

# A 方案：優化壓縮 (maxWidth=400)，降低 Base64 肥大症
function Optimize-ImageToBase64 {
    param([string]$Path)
    try {
        if (-Not (Test-Path $Path)) { return $null }
        $bmp = [System.Drawing.Image]::FromFile($Path); $maxWidth = 400; $width = $bmp.Width; $height = $bmp.Height
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
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #f8f9fa; margin: 0; padding: 15px; overflow-x: hidden; }
        .search-container { width: 100%; max-width: 800px; margin: 0 auto 10px auto; }
        #searchInput { width: 100%; padding: 14px 20px; border: 2px solid #e0e0e0; border-radius: 30px; font-size: 1rem; outline: none; box-shadow: 0 4px 6px rgba(0,0,0,0.05); width: 100%; box-sizing: border-box; }
        .filter-container { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; margin-bottom: 20px; }
        .filter-btn { background: #e0e0e0; border: none; padding: 8px 16px; border-radius: 20px; cursor: pointer; font-size: 0.9rem; transition: 0.2s; }
        .filter-btn.active { background: #3498db; color: white; }
        .grid-container { display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px; max-width: 1400px; margin: 0 auto; }
        @media (min-width: 768px) { .grid-container { grid-template-columns: repeat(4, 1fr); gap: 15px; } }
        .card { background: #fff; border-radius: 12px; padding: 12px; box-shadow: 0 4px 10px rgba(0,0,0,0.05); display: flex; flex-direction: column; position: relative; }
        .main-img-container { width: 100%; height: 0; padding-bottom: 100%; position: relative; border-radius: 8px; overflow: hidden; background: #eee; }
        .main-img { position: absolute; top: 0; left: 0; width: 100%; height: 100%; object-fit: contain; }
        .sold-badge { display: none; position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) rotate(-15deg); background: rgba(231, 76, 60, 0.95); color: white; padding: 8px 18px; font-weight: bold; border-radius: 6px; z-index: 10; border: 3px solid white; box-shadow: 0 4px 10px rgba(0,0,0,0.3); }
        .sold-out .sold-badge { display: block; }
        .sold-out .main-img { filter: grayscale(100%); opacity: 0.4; }
        .price { color: #e74c3c; font-weight: bold; font-size: 1.1rem; margin: 5px 0; }
        .old-price { text-decoration: line-through; color: #999; font-size: 0.8rem; margin-right: 5px; }
        .btn-copy { background: #3498db; color: white; border: none; padding: 10px; border-radius: 8px; cursor: pointer; font-weight: bold; margin-top: auto; }
        @media (prefers-color-scheme: dark) {
            body { background: #121212; color: #eee; }
            .card { background: #1e1e1e; }
            #searchInput { background: #222; color: #fff; border-color: #444; }
            .filter-btn { background: #333; color: #ccc; }
        }
    </style>
</head><body>
    <div class="search-container"><input type="text" id="searchInput" placeholder="🔍 搜尋商品..."></div>
    <div class="filter-container">
        <button class="filter-btn active" data-tag="all">全部清空</button>
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
    
    # 處理特價
    $PriceHtml = "<p class=`"price`">NT$ $($Item.price)</p>"
    if ($Item.desc -match "\[特價(\d+)\]") {
        $PriceHtml = "<p class=`"price`"><span class=`"old-price`">NT$ $($Item.price)</span>🔥 NT$ $($matches[1])</p>"
    }

    # A 方案：所有商品都產生壓縮圖
    $MainImage = ""
    $imgList = $Item.image -split ',' | ForEach-Object { $_.Trim() }
    if ($imgList.Count -gt 0 -and $imgList[0] -ne "") {
        $MainImage = Optimize-ImageToBase64 -Path (Join-Path $ScriptPath $imgList[0])
    }
    # 預防沒有抓到圖片的白畫面防呆
    if (-not $MainImage) { $MainImage = "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7" }

    $CardsHtml += @"
    <div class="$CardClass" data-tags="$StatusTag $($Item.desc) $($Item.name)">
        <div class="main-img-container"><div class="sold-badge">已售出</div><img class="main-img" src="$MainImage"></div>
        <h3>$($Item.name)</h3>$PriceHtml
        <button class="btn-copy">📋 複製購買資訊</button>
    </div>
"@
}

$HtmlEnd = @"
    </div>
    <script>
        let activeFilters = new Set();
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                const tag = this.dataset.tag;
                if (tag === 'all') {
                    activeFilters.clear();
                    document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                    this.classList.add('active');
                } else {
                    document.querySelector('[data-tag="all"]').classList.remove('active');
                    if (activeFilters.has(tag)) { activeFilters.delete(tag); this.classList.remove('active'); }
                    else { activeFilters.add(tag); this.classList.add('active'); }
                }
                applyFilters();
            });
        });

        function applyFilters() {
            const search = document.getElementById('searchInput').value.toLowerCase();
            document.querySelectorAll('.card').forEach(card => {
                const tags = card.dataset.tags.toLowerCase();
                const matchesSearch = tags.includes(search);
                const matchesTags = activeFilters.size === 0 || Array.from(activeFilters).every(f => tags.includes(f.toLowerCase()));
                card.style.display = (matchesSearch && matchesTags) ? 'flex' : 'none';
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
    git add . ; git commit -m "Update" ; git push origin main
    [Microsoft.VisualBasic.Interaction]::MsgBox("🎉 升級成功！`n1. 圖片已套用 400px 輕量壓縮 (A方案)`n2. 保留已售出黑白視覺圖`n3. 標籤支援複選", 64, "大功告成")
} catch {
    [Microsoft.VisualBasic.Interaction]::MsgBox("❌ 自動推播失敗。請確認網路連線。", 48, "系統錯誤")
}