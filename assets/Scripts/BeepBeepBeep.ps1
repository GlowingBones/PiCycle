# Loud_Beep_Beep_Beep.ps1
$count    = 3
$freqHz   = 2400
$duration = 600
$pauseMs  = 150

for ($i = 1; $i -le $count; $i++) {
    try {
        [Console]::Beep($freqHz, $duration)
    } catch {
        [System.Media.SystemSounds]::Beep.Play()
        Start-Sleep -Milliseconds $duration
    }
    Start-Sleep -Milliseconds $pauseMs
}
