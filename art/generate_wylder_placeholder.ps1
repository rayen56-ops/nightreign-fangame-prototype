$base = Join-Path $PSScriptRoot '..'
# Deterministic hand-built pixel placeholder. No extracted game assets.
Add-Type -AssemblyName System.Drawing
$bitmap = [Drawing.Bitmap]::new(192,1536)
$gfx = [Drawing.Graphics]::FromImage($bitmap)
$gfx.Clear([Drawing.Color]::Transparent)
function Rect($x,$y,$w,$h,$hex) {
 $brush=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($hex))
 $gfx.FillRectangle($brush,[int]$x,[int]$y,[int]$w,[int]$h); $brush.Dispose()
}
$counts=@(2,4,4,4,2,6)
for($anim=0;$anim -lt 6;$anim++) {
 for($dir=0;$dir -lt 8;$dir++) {
  for($f=0;$f -lt $counts[$anim];$f++) {
   $x=$f*32; $y=($anim*8+$dir)*32; $bob=0
   if($anim -eq 0) {$bob=$f}
   if($anim -eq 1) {$bob=$f%2}
   if($anim -eq 5 -and $f -ge 3) {
    Rect ($x+6) ($y+20) 22 5 '#202534'; Rect ($x+7) ($y+19) 13 4 '#853e43'; Rect ($x+21) ($y+18) 6 5 '#acb7c4'; continue
   }
   $y+=$bob
   Rect ($x+7) ($y+10) 18 13 '#171e2a'
   Rect ($x+5) ($y+13) 7 10 '#63313e'
   Rect ($x+7) ($y+10) 7 12 '#98454c'
   Rect ($x+5+($f%2)) ($y+21) 10 2 '#b66159'
   Rect ($x+12) ($y+12) 10 8 '#4c586a'
   Rect ($x+12) ($y+12) 3 7 '#a4aeb4'
   Rect ($x+12) ($y+20) 4 4 '#252a35'
   Rect ($x+19) ($y+20) 4 4 '#252a35'
   Rect ($x+11) ($y+23) 5 2 '#8d959f'
   Rect ($x+19) ($y+23) 5 2 '#8d959f'
   Rect ($x+13) ($y+4) 9 8 '#27303e'
   Rect ($x+14) ($y+3) 7 7 '#adb8c4'
   Rect ($x+13) ($y+6) 9 2 '#717e94'
   if($dir -notin @(3,4,5)) { Rect ($x+14) ($y+8) 7 2 '#111a25'; Rect ($x+17) ($y+8) 2 1 '#ddc585' }
   Rect ($x+10) ($y+11) 13 3 '#a34a4c'
   $sx=if($dir -in @(1,2,3)) {4} else {26}
   $sy=if($anim -eq 2) {3+$f*3} else {8}
   Rect ($x+$sx) ($y+$sy) 2 12 '#d9ded7'
   Rect ($x+$sx-2) ($y+$sy+10) 6 2 '#c2a270'
   Rect ($x+$sx) ($y+$sy+12) 2 4 '#795744'
   Rect ($x+9) ($y+15) 3 4 '#bdafa0'
   if($anim -eq 4 -and $f -eq 0) {Rect ($x+13) ($y+12) 8 6 '#eee5cc'}
  }
 }
}
$bitmap.Save((Join-Path $base 'assets/nightreign/characters/wylder/placeholder.png'),[Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose(); $bitmap.Dispose()
