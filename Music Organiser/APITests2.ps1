# Need to do two things with this script
# Get all entries
# Update the Duplicate flag on a specific entry

# Documentation
# This script pulls the data from Notion
# Loops through each entry and compares Artist and Album
# If there is a match it marks the lowest quality as Duplicate
# TODO
# Need to test when there are three identical entries

# Globals
$DatabaseId = "becb180a-c5d0-4078-bc0f-8fb075ff9d2e"
$BaseUri = "https://api.notion.com/v1/"
$DuplicateBody = $null

# Functions
function GetAllNotionRecords {
    # Call is in this form: {{url}}databases/{{databaseid}}/query
    
    $config = Get-Content -Path ".\config.json" | ConvertFrom-Json

    # We need a specific URI
    $uri = $BaseUri + "databases/" + $DatabaseId + "/query"

    # And we need Headers making sure to add Notion-Version
    $headers = @{"Content-Type" = "application/json"; "Authorization" = "Bearer " + $config.token; "Notion-Version" = "2021-08-16"}

    # Now make the call and handle any exceptions
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Header $headers
    } catch {
        Write-Host "Failed with an error " + $_.ErrorDetails.Message
    }
    return $response.results
}

function MarkRecordAsDuplicate($pageId) {
    # Call is in this form {{url}}pages/{{pageid}}

    $config = Get-Content -Path ".\config.json" | ConvertFrom-Json

    # We need a specific URI
    $uri = $BaseUri + "pages/" + $pageId

    # And we need Headers making sure to add Notion-Version
    $headers = @{"Content-Type" = "application/json"; "Authorization" = "Bearer " + $config.token; "Notion-Version" = "2021-08-16"}

    # Now make the call and handle any exceptions
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Patch -Body ($DuplicateBody | ConvertTo-Json -Depth 10) -Header $headers
    } catch {
        Write-Host "Failed with an error " + $_.ErrorDetails.Message
    }
    return $response.results

}

function CreateDuplicateBody {
    # We need to have this set up to mark pages with the Duplicate flag
    # {
    #     "properties": {
    #       "Duplicate": { "checkbox": true }
    #     }
    #   }
    $jsonBase = @{}

    # Create the properties
    $properties = @{}

    $duplicate = @{}
    $duplicate.Add("checkbox", $true)

    $properties.Add("Duplicate", $duplicate)
    $jsonBase.Add("properties", $properties)

    return $jsonBase
}

# Main
$DuplicateBody = CreateDuplicateBody

$results = GetAllNotionRecords
foreach ($result in $results) {
    # Write-Host $result.properties.'Album Name'.title[0].plain_text
    # Try marking as a duplicate
    # MarkRecordAsDuplicate -pageId $result.id
}

# How am I gonna detect duplicates

foreach ($result in $results) {
    # Never compare a record already marked as Duplicate
    if ($result.properties.Duplicate.checkbox -eq $true) {
        continue
    }
    Write-Host "RESULT: " $result.properties.'Album Name'.title[0].plain_text
    foreach ($compare in $results) {
        Write-Host "COMPARE: " $compare.properties.'Album Name'.title[0].plain_text
        # Never compare the same entries
        if ($result.id -eq $compare.id) {
            continue
        }
        # Never compare a record already marked as Duplicate
        if ($compare.properties.Duplicate.checkbox -eq $true) {
            continue
        }
        # let's see if the artist is the same
        if ($result.properties.Artist.rich_text[0].plain_text -eq $compare.Properties.Artist.rich_text[0].plain_text) {
            # Artist matches
            if ($result.properties.'Album Name'.title[0].plain_text -eq $compare.properties.'Album Name'.title[0].plain_text) {
                # OK Artist and Album match
                # Mark the lowest quality one as Duplicate
                if ($result.properties.Type.select.name -eq "Flac") {
                    MarkRecordAsDuplicate -pageId $compare.id
                } else {
                    MarkRecordAsDuplicate -pageId $result.id
                }
            }
        }

    }
}



