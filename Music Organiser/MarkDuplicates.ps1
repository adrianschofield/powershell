# Need to do two things with this script
# Get all entries
# Update the Duplicate flag on a specific entry

# Documentation
# This script pulls the data from Notion
# Loops through each entry and compares Artist and Album
# If there is a match it marks the lowest quality as Duplicate
# TODO - need to test pagination

# Globals
$DatabaseId = "becb180a-c5d0-4078-bc0f-8fb075ff9d2e"
$BaseUri = "https://api.notion.com/v1/"
$DuplicateBody = $null

# Functions
function GetAllNotionRecords {
    $allResults = @()
    # Call is in this form: {{url}}databases/{{databaseid}}/query
    
    $config = Get-Content -Path ".\config.json" | ConvertFrom-Json

    # We need a specific URI
    $uri = $BaseUri + "databases/" + $DatabaseId + "/query"
    # But we also need to keep the original
    # $origUri = $uri

    # And we need Headers making sure to add Notion-Version
    $headers = @{"Content-Type" = "application/json"; "Authorization" = "Bearer " + $config.token; "Notion-Version" = "2021-08-16"}

    # TODO Handle Pagination
    # The Start_cursor needs to be in the body :-( 
    $jsonCursor = @{}
    # $jsonCursor = CreatePaginationBody -start_cursor 0
    # Now make the call and handle any exceptions
    
    do {
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Header $headers -Body ($jsonCursor | ConvertTo-Json -Depth 10)
            Write-Host $response.has_more " " $jsonCursor.start_cursor
            $allResults += $response.results
        } catch {
            Write-Host "Failed with an error " + $_.ErrorDetails.Message
        }
        # This feels lame because I check this twice, once to get the next cursor
        # and once for the loop
        # TODO can I make this more elegant?
        if ($response.has_more -eq $true) {
            $jsonCursor = @{}
            $jsonCursor = CreatePaginationBody -start_cursor $response.next_cursor
        }
    }while ($response.has_more -eq $true)
    
    
    return $allResults
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

function CreatePaginationBody ($start_cursor) {
    $jsonBase = @{}
    $jsonBase.Add("start_cursor", $start_cursor.ToString())
    return $jsonBase
}

# Main

# Will need this later but only want to create the object once
$DuplicateBody = CreateDuplicateBody

# Grab all the data from Notion
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
    # DBG
    # Write-Host "RESULT: " $result.properties.'Album Name'.title[0].plain_text

    foreach ($compare in $results) {

        # Never compare the same entries
        if ($result.id -eq $compare.id) {
            continue
        }
        # Never compare a record already marked as Duplicate
        if ($compare.properties.Duplicate.checkbox -eq $true) {
            continue
        }

        # DBG
        # Write-Host "COMPARE: " $compare.properties.'Album Name'.title[0].plain_text

        # Let's see if the artist is the same
        if ($result.properties.Artist.rich_text[0].plain_text -eq $compare.properties.Artist.rich_text[0].plain_text) {
            # Artist matches
            if ($result.properties.'Album Name'.title[0].plain_text -eq $compare.properties.'Album Name'.title[0].plain_text) {
                # OK Artist and Album match
                # Mark the lowest quality one as Duplicate
                # If one of the options is on brennan music then duplicate the other
                # Because this is a very lazy sort I need to mark the entries as duplicate in both
                # Notion and the results data
                if ($result.properties.Location.rich_text[0].plain_text -like "*brennan*") {
                    Write-Host "Marking " $compare.properties.Location.rich_text[0].plain_text " as duplicate"
                    MarkRecordAsDuplicate -pageId $compare.id
                    $compare.properties.Duplicate.checkbox = $true
                    continue
                } elseif ($compare.properties.Location.rich_text[0].plain_text -like "*brennan*") {
                    Write-Host "Marking " $result.properties.Location.rich_text[0].plain_text " as duplicate"
                    MarkRecordAsDuplicate -pageId $result.id
                    $result.properties.Duplicate.checkbox = $true
                    continue
                }
                if ($result.properties.Type.select.name -eq "Flac") {
                    Write-Host "Marking " $compare.properties.Location.rich_text[0].plain_text " as duplicate"
                    MarkRecordAsDuplicate -pageId $compare.id
                    $compare.properties.Duplicate.checkbox = $true
                } else {
                    Write-Host "Marking " $result.properties.Location.rich_text[0].plain_text " as duplicate"
                    MarkRecordAsDuplicate -pageId $result.id
                    $result.properties.Duplicate.checkbox = $true
                }
            }
        }

    }
}



