# Documentation

# Globals
$DatabaseId = "becb180a-c5d0-4078-bc0f-8fb075ff9d2e"
$BaseUri = "https://api.notion.com/v1/"
$Destination = "\\server\music"
$JsonFilter = @{}

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
    # Now make the call and handle any exceptions
    do {
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Post -Header $headers -Body ($JsonFilter | ConvertTo-Json -Depth 10)
            $allResults += $response.results
        } catch {
            Write-Host "Failed with an error " + $_.ErrorDetails.Message
        }
        # This feels lame because I check this twice, once to get the next cursor
        # and once for the loop
        # TODO can I make this more elegant?
        if ($response.has_more -eq $true) {
            if ($null -eq $JsonFilter.start_cursor) {
                $JsonFilter.Add("start_cursor", $response.next_cursor.ToString())
            } else {
                $JsonFilter.start_cursor = $response.next_cursor.ToString()
            }
        }
    }while ($response.has_more -eq $true)
    
    
    return $allResults
}

function CreateFilter {
    # We need a JSON object like this:
    # { 
    # "filter": {
    #     "property": "Done",
    #     "checkbox": {
    #         "equals": true
    #     }
    #   }
    # }
    $jsonBase = @{}
    $filter = @{}

    # Create the properties
    # We want the non duplicates
    $checkbox = @{}
    $checkbox.Add("equals", $false)
    # Now add values
    $filter.Add("property", "Duplicate")
    # And other objects
    $filter.Add("checkbox", $checkbox)
    $jsonBase.Add("filter", $filter)

    return $jsonBase
}

# Main

$JsonFilter = CreateFilter

$results = GetAllNotionRecords

# OK we need to copy the folders that we found to the new share.
# This command gets the job done
# copy-item -Path "\\server\BrennanMusic\Alanis Morissette\Under Rug Swept" -Destination "\\server\music\Alanis Morissette\Under Rug Swept" -Recurse

foreach ($result in $results) {
    $source = $result.properties.Location.rich_text[0].plain_text
    # We need the artist and album to create the destination
    $dest = $Destination + "\" + $result.properties.Artist.rich_text[0].plain_text + "\" + $result.properties.'Album Name'.title[0].plain_text

    # Copy-Item doesn't work where paths contain square brackets so I'm going
    # to be lazy and just skip them
    # if ($source -like "*``[" -or $source -like "*``]") {
    #     Write-Host "failed to copy " $source
    #     continue
    # }

    # Now do the copy
    Write-Host $source $dest
    # Use Robocopy because Copy-Item was giving me grief with paths with []
    # copy-item -Path $source -Destination $dest -Recurse
    $command = "robocopy `"" + $source + "`" `"" + $dest + "`" /MIR /NFL /NDL /NJH /NJS /nc /ns /np"
    Invoke-Expression $command

    # We need to check the Cover Art
    # Sonos requires folder.jpg
    # TODO this needs to be way more robust
    $artPath = $dest + "\folder.jpg"

    $artFiles = @(Get-ChildItem -Path $dest -Recurse -Include *.jpg | Sort-Object -Property Length)

    if ($artFiles.Count -eq 0) {
        Write-Host $artPath " has no art"
        continue
    }
    
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
}

