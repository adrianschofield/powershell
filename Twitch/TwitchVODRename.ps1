# Globals

$FolderName = "D:\temp\twitchvods"
$BaseUri = "https://api.twitch.tv/helix/"
$Includedate = $true

# Functions
function GetVodsFromTwitch() {
    # Sample URI:
    # https://api.twitch.tv/helix/videos?user_id={{user-id}}&after=eyJiIjp7Ik9mZnNldCI6MH0sImEiOnsiT2Zmc2V0Ijo0MH19

    # Load the configuration
    $config = Get-Content -Path ".\Twitch\config.json" | ConvertFrom-Json

    # We need a specific URI for videos
    $videosUri = $BaseUri + "videos?user_id=" + $config.user_id

    # And we need headers
    $headers = @{   "Content-Type" = "application/json"; 
                    "Authorization" = "Bearer " + $config.token; 
                    "Client-ID" = $config.client_id; 
                    "Accept" = "application/vnd.twitchtv.v5+json"}

    # Variables required for handling the response                
    $response = $null
    $results = $null

    # Set up the uri for the first call
    $uri = $videosUri
    do {
        
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Get -Header $headers
        } catch {
            Write-Host "Failed with an error " + $_.ErrorDetails.Message
        }
        $results += $response.data

        # TODO I check for pagination twice - there must be an easier way
        # Check to see if we need to request more pages
        if ($null -ne $response.pagination.cursor) {
            $uri = $videosUri + "&after=" + $response.pagination.cursor
        }

    } while ($null -ne $response.pagination.cursor)

    # Data returned is just the list of videos
    return $results
}

# Main

# Get all the VODS from Twitch
$videos = GetVodsFromTwitch

# Get all the files from the folder
$files = Get-ChildItem -Path $FolderName -File

# Go through all the files and see if there is a match in the VODS list
foreach ($file in $files) {
    # DBG
    Write-Host $file.Name
    $fileId = $file.Name.Split("-")[0]

    foreach ($video in $videos) {
        # Write-Host $video.id
        if ($fileId -eq $video.id) {
            
            # OK this is the video we need
            # Get the strings we need to rename the file
            $created = $video.created_at
            $title = $video.title

            # Let's create the date string we need
            $date = $created.Year.ToString() + $created.Month.ToString() + $created.Day.ToString()

            # DBG
            # Write-Host $title $date

            # New filename
            if ($Includedate) {
                $destination = $FolderName + "\" + $date + " " +  $title + ".mp4"
            } else {
                 $destination = $FolderName + "\" +  $title + ".mp4"
            }

            # And now rename the file
            try {
                Move-Item -LiteralPath $file.FullName -Destination $destination
            } catch {
                Write-Host "Could not rename " + $file.Name + " to " $destination
            }

        }
    }
}