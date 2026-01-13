param(
  [string]$OutputDir = "C:\Temp",
  [int]$IntervalSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Runtime.InteropServices.WindowsRuntime

if ([Threading.Thread]::CurrentThread.ApartmentState -ne "STA") {
  throw "This script must be run in STA. Use: powershell.exe -STA -File $PSCommandPath"
}

if (-not (Test-Path -LiteralPath $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

function Get-WinRTType {
  param([Parameter(Mandatory)][string]$FullName)
  $t = [Type]::GetType("$FullName, Windows, ContentType=WindowsRuntime")
  if (-not $t) { throw "WinRT type not found: $FullName" }
  $t
}

function Await-WinRT {
  param([Parameter(Mandatory)]$Async)
  $ct = [Threading.CancellationToken]::None
  $task = [System.WindowsRuntimeSystemExtensions]::AsTask($Async, $ct)
  $task.GetAwaiter().GetResult()
}

function Capture-AllScreens {
  param(
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$Timestamp
  )

  $i = 1
  foreach ($scr in [System.Windows.Forms.Screen]::AllScreens) {
    $b = $scr.Bounds
    $path = Join-Path $Dir ("screenshot-$Timestamp-monitor{0}.png" -f $i)

    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    try {
      $g.CopyFromScreen($b.Location, (New-Object System.Drawing.Point 0,0), $b.Size)
      $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
      $g.Dispose()
      $bmp.Dispose()
    }
    $i++
  }
}

function Capture-WebcamPhoto {
  param(
    [Parameter(Mandatory)][string]$Dir,
    [Parameter(Mandatory)][string]$Timestamp
  )

  $MediaCaptureT = Get-WinRTType "Windows.Media.Capture.MediaCapture"
  $InitSettingsT = Get-WinRTType "Windows.Media.Capture.MediaCaptureInitializationSettings"
  $ModeEnumT     = Get-WinRTType "Windows.Media.Capture.StreamingCaptureMode"
  $EncPropsT     = Get-WinRTType "Windows.Media.MediaProperties.ImageEncodingProperties"
  $StorageFolderT= Get-WinRTType "Windows.Storage.StorageFolder"
  $CollisionEnumT= Get-WinRTType "Windows.Storage.CreationCollisionOption"

  $cap = $null
  try {
    $cap = [Activator]::CreateInstance($MediaCaptureT)

    $settings = [Activator]::CreateInstance($InitSettingsT)
    $settings.StreamingCaptureMode = [Enum]::Parse($ModeEnumT, "Video")

    Await-WinRT ($cap.InitializeAsync($settings))

    $folder = Await-WinRT ($StorageFolderT.GetFolderFromPathAsync($Dir))
    $name = "photo-$Timestamp.jpg"
    $file = Await-WinRT ($folder.CreateFileAsync($name, [Enum]::Parse($CollisionEnumT, "ReplaceExisting")))

    $enc = $EncPropsT.CreateJpeg()
    Await-WinRT ($cap.CapturePhotoToStorageFileAsync($enc, $file))
  }
  finally {
    if ($cap) { $cap.Dispose() }
  }
}

while ($true) {
  $ts = Get-Date -Format "yyyyMMdd-HHmmss"

  Capture-AllScreens -Dir $OutputDir -Timestamp $ts

  try {
    Capture-WebcamPhoto -Dir $OutputDir -Timestamp $ts
  } catch {
    Write-Host ("Camera capture failed: {0}" -f $_.Exception.Message)
  }

  Start-Sleep -Seconds $IntervalSeconds
}
