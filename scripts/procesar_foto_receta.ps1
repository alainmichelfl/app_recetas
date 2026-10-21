<#
.SYNOPSIS
  Script de optimización y despliegue automático de fotografías culinarias para Jitomate y Cebolla.
.DESCRIPTION
  Toma una imagen en alta resolución generada por el estudio fotográfico, la escala a 1024px con compresión
  bicúbica de alta calidad (88%), y la coloca tanto en assets/ como en web/recetas/ para disponibilidad
  offline y en web CDN.
.EXAMPLE
  .\scripts\procesar_foto_receta.ps1 -SourcePath "C:\ruta\foto.jpg" -NombreDestino "tinga_de_pollo"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,

    [Parameter(Mandatory=$true)]
    [string]$NombreDestino
)

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $SourcePath)) {
    Write-Error "El archivo de origen no existe: $SourcePath"
    exit 1
}

$nombreLimpio = $NombreDestino.ToLower().Trim() -replace '\.jpg$', '' -replace '[^a-z0-9_]', '_'
$archivoFinal = "$nombreLimpio.jpg"

New-Item -ItemType Directory -Force -Path 'web\recetas' | Out-Null
New-Item -ItemType Directory -Force -Path 'assets' | Out-Null

$dstAssets = Join-Path 'assets' $archivoFinal
$dstWeb = Join-Path 'web\recetas' $archivoFinal

$img = [System.Drawing.Image]::FromFile($SourcePath)
$ratio = $img.Height / $img.Width
$maxWidth = 1024
$newWidth = [Math]::Min($maxWidth, $img.Width)
$newHeight = [int]($newWidth * $ratio)

$bmp = New-Object System.Drawing.Bitmap $newWidth, $newHeight
$graph = [System.Drawing.Graphics]::FromImage($bmp)
$graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graph.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$graph.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graph.DrawImage($img, 0, 0, $newWidth, $newHeight)

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]88)

$bmp.Save($dstAssets, $codec, $encoderParams)
$bmp.Save($dstWeb, $codec, $encoderParams)

$bmp.Dispose()
$graph.Dispose()
$img.Dispose()

$pesoAssets = (Get-Item $dstAssets).Length / 1KB
Write-Host "✅ Fotografía procesada con éxito: $archivoFinal" -ForegroundColor Green
Write-Host "   - Tamaño optimizado: $([Math]::Round($pesoAssets, 1)) KB"
Write-Host "   - Copiada a: $dstAssets"
Write-Host "   - Copiada a: $dstWeb"
Write-Host "   - URL CDN oficial: https://raw.githubusercontent.com/alainmichelfl/app_recetas/main/web/recetas/$archivoFinal"
