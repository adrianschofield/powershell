# Sample code to call Notion APIs from Powershell.

# Globals

$DatabaseId = "becb180a-c5d0-4078-bc0f-8fb075ff9d2e"
$BaseUri = "https://api.notion.com/v1/"


# Create the base object
$jsonBase = @{}

# Functions

# Create the Json object

function CreateJsonObject ($artist, $album, $location, $flac) {
    
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

}

function AddDatabaseEntry () {

    $config = Get-Content -Path ".\config.json" | ConvertFrom-Json

    # We need a specific URI
    $pagesUri = $BaseUri + "pages"

    # And we need Headers making sure to add Notion-Version
    $headers = @{"Content-Type" = "application/json"; "Authorization" = "Bearer " + $config.token; "Notion-Version" = "2021-08-16"}

    # Now make the call and handle any exceptions
    try {
        Invoke-RestMethod -Uri $pagesUri -Method Post -Body ($jsonBase | ConvertTo-Json -Depth 10) -Header $headers
    } catch {
        Write-Host "Failed with an error " + $_.ErrorDetails.Message
    }
}

# Code

# OK first let's create some code to create an entry in the database
# We need to provide as a minimum Album Title, Artist and Location and set the type
# We need to create the relevant JSON based on these values
# and then call the API

$artist = "Pink Floyd"
$album = "The Darkside of the Moon"
$location = "\\server\BrennanMusic\Pink Floyd\The Dark Side Of The Moon"

# Create the JSON this is so messy
CreateJsonObject -artist $artist -album $album -location $location -flac $true

# Now make the REST call

AddDatabaseEntry
