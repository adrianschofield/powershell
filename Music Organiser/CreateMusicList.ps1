# Documentation
# So far this script can access all four shares
# Find each Album
# Determine if it's FLAC or MP3
# Write a relevant entry in the Notion database
# Never seems to break the Notion rate limit and so can't tell if that part of
# the code actually works

# Globals
$shares = @("\\server\BrennanMusic", "\\server\Music_mp3", "\\server\Music_old", "\\server\Music_Dads")
$DatabaseId = "becb180a-c5d0-4078-bc0f-8fb075ff9d2e"
$BaseUri = "https://api.notion.com/v1/"

# Functions

# GetDataFromPath splits up a path and returns artist or album
# If $Album is $true album name is returned, if $false returns artist
# The code relies on the path being something like
# \\Server\Share\Artist\Album
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

# CreateJsonObject creates the correct JSON type object that can be used with the Notion API
# This is very specific to the format of the Database that you set up in Notion
# Personally I think the requirements for the Notion API are overly complex which you'll see
# in the code
# If the $flac is $true then the entry is marked as FLAC, if $false then marked as MP3
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

# AddDatabaseEntry makes the call to Notion to add an entry into the Database
function AddDatabaseEntry ($object) {

    # TODO probably should do this in main to save constantly loading the file
    # Load the config file which contains our token
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
            Write-Host "Rate Limit hit so Pausing"
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

# CheckForFlac takes a path, opens the files in it and sees if they are FLAC, MP3 or WMA
# and returns appropriately
function CheckForFlac ($path) {
    # Set FLAC as default because most of my albums are lossless copies
    $typeIsFlac = $true

    # Get all the files based on the path
    $results = Get-ChildItem -Path $path

    foreach ($result in $results) {
        # Check if this is an audio file
        if ($result.Extension.ToLower() -ne ".flac" -and $result.Extension.ToLower() -ne ".mp3" -and $result.Extension.ToLower() -ne ".wma") {
            # Not an audio file let's try the next one
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

# Loop through all our shares defined in Globals
foreach ($share in $shares) {

    # TODO see if I can work out how to Exclude recycle properly
    $paths = Get-ChildItem -Path $share -Recurse -Directory -Exclude recycle*

    # Loop through all the paths we have adding an entry to the Notion database
    # every time
    foreach ($path in $paths) {
        $album = GetDataFromPath -Path $path.FullName -Album $true
        # Because we get all folders the first ones will just be the artist folders
        # So if album is "" skip to next
        if ($album -eq "" -or $null -eq $album) {
            continue
        }
        $artist = GetDataFromPath -Path $path.FullName -Album $false
        $location = $path.FullName

        # We need to know if this is FLAC or MP3
        $flac = $true
        $flac = CheckForFlac -path $path.FullName
        # DBG
        # Write-Host $album $artist $location
        
        # OK we got an album we need to add it to the database
        # Create the JSON this is so messy
        $object = CreateJsonObject -artist $artist -album $album -location $location -flac $flac

        # Now make the REST call
        AddDatabaseEntry -object $object
    }
}