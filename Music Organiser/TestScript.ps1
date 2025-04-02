# Try and run Robocopy from inside powershell

$dest = "\\server\BrennanMusic\ABBA\18 Hits"
# We need to check the Cover Art
    # Sonos requires folder.jpg
    # TODO this needs to be way more robust
    $artPath = $dest + "\folder.jpg"

    $artFiles = @(Get-ChildItem -Path $dest -Recurse -Include *.exe | Sort-Object -Property Length)
    
    if (!(Test-Path -Path $artPath )) {
        # OK folder.jpg doesn't exist let's see what options we have
        if ($artFiles.Count -gt 0) {
            # If there's only one file then we don't have a lot of choice
            if ($artFiles.Count -eq 1) {
                Copy-Item -Path $artFiles[0].FullName -Destination $artPath
            } else {
                Copy-Item -Path $artFiles[$artFiles.Count - 1].FullName -Destination $artPath
            }
        }

    }
