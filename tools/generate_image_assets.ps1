Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function New-Bitmap($w, $h, [bool]$transparent = $true) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    if ($transparent) { $g.Clear([System.Drawing.Color]::Transparent) }
    return @($bmp, $g)
}

function Brush($hex, $alpha = 255) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B))
}

function Pen($hex, $width, $alpha = 255) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($hex)
    $p = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B)), $width
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    return $p
}

function Save-Png($bmp, $g, $path) {
    $g.Dispose()
    $bmp.Save((Join-Path (Get-Location) $path), [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function Fill-Polygon($g, $points, $brush) {
    $g.FillPolygon($brush, [System.Drawing.PointF[]]$points)
}

$W = 1280
$H = 720

# Stationary sky and mountains layer.
$res = New-Bitmap $W $H $false; $bmp = $res[0]; $g = $res[1]
$g.Clear([System.Drawing.ColorTranslator]::FromHtml('#9bdcff'))
$g.FillEllipse((Brush '#fff1a8'), 995, 58, 108, 108)
$baseY = [single]($H * 0.62)
$mountains = @(
    @(-120,$baseY, 120,($H*0.28), 360,$baseY),
    @(250,$baseY, 545,($H*0.22), 880,$baseY),
    @(730,$baseY, 1020,($H*0.30), 1360,$baseY)
)
foreach ($m in $mountains) {
    Fill-Polygon $g @(
        [System.Drawing.PointF]::new($m[0],$m[1]), [System.Drawing.PointF]::new($m[2],$m[3]), [System.Drawing.PointF]::new($m[4],$m[5])
    ) (Brush '#8ab0c3')
    Fill-Polygon $g @(
        [System.Drawing.PointF]::new($m[2],$m[3]), [System.Drawing.PointF]::new($m[4],$m[5]), [System.Drawing.PointF]::new($m[2] + 60,$baseY)
    ) (Brush '#6f98ad')
}
Save-Png $bmp $g 'assets\sky_mountains.png'

# Far hills layer, transparent except hills.
$res = New-Bitmap $W $H $true; $bmp = $res[0]; $g = $res[1]
$y = [single]($H * 0.66)
Fill-Polygon $g @(
    [System.Drawing.PointF]::new(-80,$H), [System.Drawing.PointF]::new(80,$y+30), [System.Drawing.PointF]::new(260,$y-35),
    [System.Drawing.PointF]::new(470,$y+18), [System.Drawing.PointF]::new(700,$y-52), [System.Drawing.PointF]::new(970,$y+20),
    [System.Drawing.PointF]::new($W+120,$H)
) (Brush '#79bf83')
Fill-Polygon $g @(
    [System.Drawing.PointF]::new(-120,$H), [System.Drawing.PointF]::new(150,$y+72), [System.Drawing.PointF]::new(410,$y+8),
    [System.Drawing.PointF]::new(740,$y+68), [System.Drawing.PointF]::new(1060,$y+5), [System.Drawing.PointF]::new($W+160,$H)
) (Brush '#5ba874')
Save-Png $bmp $g 'assets\far_hills.png'

# Near trees layer, transparent except trees and shrubs.
$res = New-Bitmap $W $H $true; $bmp = $res[0]; $g = $res[1]
for ($i = 0; $i -lt 8; $i++) {
    $x = [single]($i * 180 + 35)
    $trunkH = [single](92 + (($i * 29) % 52))
    $base = [single]($H * 0.86)
    $g.FillRectangle((Brush '#6d5136'), $x - 9, $base - $trunkH, 18, $trunkH)
    $g.FillEllipse((Brush '#26734d'), $x - 46, $base - $trunkH - 64, 92, 92)
    $g.FillEllipse((Brush '#2d8a58'), $x - 62, $base - $trunkH - 26, 64, 64)
    $g.FillEllipse((Brush '#1f6845'), $x - 2, $base - $trunkH - 24, 68, 68)
    for ($j = 0; $j -lt 4; $j++) {
        $lx = [single]($x + 84 + $j * 17.6)
        $ly = [single]($base - 22 + [Math]::Sin($j) * 8)
        $g.FillEllipse((Brush '#2f995f'), $lx - 17.6, $ly - 17.6, 35.2, 35.2)
    }
}
Save-Png $bmp $g 'assets\near_trees.png'

# Ground layer, transparent above the ground strip.
$res = New-Bitmap $W $H $true; $bmp = $res[0]; $g = $res[1]
$groundY = [single]($H - 88)
$g.FillRectangle((Brush '#326242'), 0, $groundY, $W, 88)
for ($i = 0; $i -lt 16; $i++) {
    $x = [single]($i * 82)
    $bladeH = [single](18 + (($i * 17) % 32))
    $g.DrawLine((Pen '#54b35f' 4), $x, $groundY + 8, $x + 15, $groundY - $bladeH)
    $g.DrawLine((Pen '#79ca67' 3), $x + 28, $groundY + 10, $x + 17, $groundY - $bladeH * 0.75)
}
for ($i = 0; $i -lt 7; $i++) {
    $x = [single]($i * 210 + 35)
    $g.FillEllipse((Brush '#254c35'), $x - 18, $groundY + 10, 36, 36)
}
Save-Png $bmp $g 'assets\ground.png'

# Bubble sprite, transparent background.
$res = New-Bitmap 96 96 $true; $bmp = $res[0]; $g = $res[1]
$g.FillEllipse((Brush '#8ce6ff' 100), 17, 17, 62, 62)
$g.DrawEllipse((Pen '#dbfbff' 5), 17, 17, 62, 62)
$g.FillEllipse((Brush '#ffffff' 185), 36, 32, 16, 16)
$g.DrawArc((Pen '#ffffff' 3 92), 42, 47, 32, 32, 20, 130)
Save-Png $bmp $g 'assets\bubble.png'

# Sharp plant sprite, transparent background. Origin is expected near bottom center in code.
$res = New-Bitmap 128 160 $true; $bmp = $res[0]; $g = $res[1]
Fill-Polygon $g @(
    [System.Drawing.PointF]::new(40,150), [System.Drawing.PointF]::new(47,58), [System.Drawing.PointF]::new(64,18),
    [System.Drawing.PointF]::new(81,58), [System.Drawing.PointF]::new(88,150)
) (Brush '#1f7a43')
$outline = [System.Drawing.PointF[]]@([System.Drawing.PointF]::new(40,150),[System.Drawing.PointF]::new(47,58),[System.Drawing.PointF]::new(64,18),[System.Drawing.PointF]::new(81,58),[System.Drawing.PointF]::new(88,150),[System.Drawing.PointF]::new(40,150))
$g.DrawLines((Pen '#b8ff8d' 3), $outline)
foreach ($side in @(-1, 1)) {
    for ($i = 0; $i -lt 3; $i++) {
        $yy = [single](120 - $i * 26)
        Fill-Polygon $g @(
            [System.Drawing.PointF]::new(64 + $side * 8,$yy),
            [System.Drawing.PointF]::new(64 + $side * (44 + $i * 6),$yy - 16),
            [System.Drawing.PointF]::new(64 + $side * 10,$yy - 24)
        ) (Brush '#6bbb48')
    }
}
$g.FillEllipse((Brush '#eaffbd'), 56, 10, 16, 16)
Save-Png $bmp $g 'assets\sharp_plant.png'

# Mosquito sprite, transparent background.
$res = New-Bitmap 128 96 $true; $bmp = $res[0]; $g = $res[1]
$g.FillEllipse((Brush '#d9f2ff' 120), 16, 20, 40, 32)
$g.FillEllipse((Brush '#d9f2ff' 120), 72, 20, 40, 32)
$g.FillEllipse((Brush '#40313c'), 49, 33, 30, 30)
$g.DrawLine((Pen '#261b22' 3), 78, 48, 112, 39)
$g.DrawLine((Pen '#d94f4f' 2), 112, 39, 126, 41)
for ($leg = 0; $leg -lt 3; $leg++) {
    $yy = [single](42 + $leg * 8)
    $g.DrawLine((Pen '#261b22' 2), 57, $yy, 28, $yy + 18)
    $g.DrawLine((Pen '#261b22' 2), 71, $yy, 100, $yy + 18)
}
Save-Png $bmp $g 'assets\mosquito.png'
