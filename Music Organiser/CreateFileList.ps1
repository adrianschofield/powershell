# Documentation
# So far this script can access all three shares
# Find each Album
# Determine if it's FLAC or MP3
# Write a relevant entry in the Notion database
# Currently hardcoded to only do 30 records 10 from each share
# Never seems to break the Notion rate limit and so can't tell if that part of
# the code actually works

# TODO More testing required on FLAC code, 
# \\server\Music_mp3\All Saints\Saints & Sinners [UK] tagged as FLAC

# Globals
$shares = @("\\server\Music_mp3", "\\server\BrennanMusic", "\\server\Music_old")
$DatabaseId = "becb180a-c5d0-4078-bc0f-8fb075ff9d2e"
$BaseUri = "https://api.notion.com/v1/"

# Functions
function GetDataFromPath {
    param(  [string]$Path,
            [bool]$Album )

    # If $Album -eq $true
    # we need to return everything after the fifth slash, if it exists
    # If $Album -eq $false
    # we need to return everything between the fourth and fifth slash if it exists
    
    # Number of back slashes we find in the string
    $slashCount = 0

    # Loop through the string finding backslashes
    foreach($char in $Path.ToCharArray() ) {
        if($char -eq "\") {
            $slashCount++
        }
    }
    
    if($Album -eq $true) {
        if($slashCount -eq 5) {
            $posOfSlash = 0
            for($i = 0; $i -lt 4; $i++ ) {
                $posOfSlash = $Path.IndexOf('\', $posOfSlash + 1)
            }
            $albumName = $Path.Substring($posOfSlash + 1, $Path.Length - $posOfSlash - 1)
            return $albumName
        } else {
            return ""
        }
    } else {
        # Artist is more tricky here's an example:
        # \\192.168.0.31\music\Bryan Adams\MTV Unplugged
        if($slashCount -eq 5) {
            $posOfSlash = 0
            for($i = 0; $i -lt 3; $i++ ) {
                $posOfSlash = $Path.IndexOf('\', $posOfSlash + 1)
            }
            $artistName = $Path.Substring($posOfSlash + 1, $Path.IndexOf('\', $posOfSlash + 1) - $posOfSlash - 1)
            return $artistName
        } else {
            return ""
        }
    }
}

function CreateJsonObject ($artist, $album, $location, $flac) {
    $jsonBase = @{}

    # Create the parent data - easy
    $parent = @{"database_id"=$DatabaseId;}

    # OK now the properties
    $properties = @{}

    # First entry is Album Name
    $albumName = @{}
    # That contains a title entry which is an array
    $albumTitle = New-Object System.Collections.ArrayList
    # This contains objects (only one in our case)
    $albumTitleText = @{}
    # Then the final entry
    $albumTitleContent = @{"content" = $album;}

    # Now add them backwards

    $albumTitleText.Add("text", $albumTitleContent)
    $albumTitle += $albumTitleText
    $albumName.Add("title", $albumTitle)
    $properties.Add("Album Name", $albumName)

    # second entry is Artist
    $artistName = @{}
    # That contains a title entry which is an array
    $artistTitle = New-Object System.Collections.ArrayList
    # This contains objects (only one in our case)
    $artistTitleText = @{}
    # Then the final entry
    $artistTitleContent = @{"content" = $artist;}

    # Now add them backwards

    $artistTitleText.Add("text", $artistTitleContent)
    $artistTitle += $artistTitleText
    $artistName.Add("rich_text", $artistTitle)
    $properties.Add("Artist", $artistName)

    # third entry is Location
    $locationName = @{}
    # That contains a title entry which is an array
    $locationTitle = New-Object System.Collections.ArrayList
    # This contains objects (only one in our case)
    $locationTitleText = @{}
    # Then the final entry
    $locationTitleContent = @{"content" = $location;}

    # Now add them backwards

    $locationTitleText.Add("text", $locationTitleContent)
    $locationTitle += $locationTitleText
    $locationName.Add("rich_text", $locationTitle)
    $properties.Add("Location", $locationName)

    # last entry is Type (slightly easier)
    $typeName = @{}

     # Then the final entry
    if ($flac -eq $true) {   
        $selectContent = @{"name" = "Flac";}
    } else {
        $selectContent = @{"name" = "MP3";}
    }

    # Now add them backwards

    $typeName.Add("select", $selectContent)
    $properties.Add("Type", $typeName)


    $jsonBase.Add("properties", $properties)
    $jsonBase.Add("parent",$parent)

    return $jsonBase

}

function AddDatabaseEntry ($object) {

    $config = Get-Content -Path ".\config.json" | ConvertFrom-Json

    # We need a specific URI
    $pagesUri = $BaseUri + "pages"

    # And we need Headers making sure to add Notion-Version
    $headers = @{"Content-Type" = "application/json"; "Authorization" = "Bearer " + $config.token; "Notion-Version" = "2021-08-16"}

    # Now make the call and handle any exceptions
    try {
        Invoke-RestMethod -Uri $pagesUri -Method Post -Body ($object | ConvertTo-Json -Depth 10) -Header $headers
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 429) {
            # We hit a rate limit, let's wait for 1 second and retry
            Start-Sleep -Seconds 1
            try {
                Invoke-RestMethod -Uri $pagesUri -Method Post -Body ($object | ConvertTo-Json -Depth 10) -Header $headers
            } catch {
                Write-Host "Failed with an error on Rate Limit Retry" + $_.ErrorDetails.Message
                Write-Host "Album: " $object.properties.'Album Name'.title
            }
        }
        Write-Host "Failed with an error " + $_.ErrorDetails.Message
        Write-Host "Album: " $object.properties.'Album Name'.title
    }
}

function CheckForFlac ($path) {
    $typeIsFlac = $true
    $results = Get-ChildItem -Path $path
    foreach ($result in $results) {
        if ($result.Extension.ToLower() -ne ".flac" -and $result.Extension.ToLower() -ne ".mp3" -and $result.Extension.ToLower() -ne ".wma") {
            # not a music file let's try the next one
            continue
        } elseif ($result.Extension.ToLower() -eq ".mp3" -or $result.Extension.ToLower() -eq ".wma") {
            $typeIsFlac = $false
            break
        } else {
            break
        }
    }
    return $typeIsFlac
}

# Main

# We need the folders in this format
# $artist = "Pink Floyd"
# $album = "The Darkside of the Moon"
# $location = "\\server\BrennanMusic\Pink Floyd\The Dark Side Of The Moon"
$loop = 0
$count = 0
foreach ($share in $shares) {
    $paths = Get-ChildItem -Path $share -Recurse -Directory -Exclude recycle*

    foreach ($path in $paths) {
        if ($loop -eq 10) {
            $loop = 0
            break
        }
        $album = GetDataFromPath -Path $path.FullName -Album $true
        # Because we get all folders the first ones will just be the artist folders
        # So if album is "" skip to next
        if ($album -eq "" -or $null -eq $album) {
            continue
        }
        $count++
        $artist = GetDataFromPath -Path $path.FullName -Album $false
        $location = $path.FullName

        # We need to know if this is FLAC or MP3
        $flac = $true
        $flac = CheckForFlac -path $path.FullName
        # Write-Host $album $artist $location
        # OK we got an album we need to add it to the database
        # Create the JSON this is so messy
        $object = CreateJsonObject -artist $artist -album $album -location $location -flac $flac

        # Now make the REST call
        AddDatabaseEntry -object $object

        $loop++

    }

    Write-Host "Count: " $count
}