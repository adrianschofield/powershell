# Relies on this module https://www.powershellgallery.com/packages/ID3/1.1
# Install-Module -Name ID3

# Globals

$MusicPath  = "z:\"

# Functions

function GetArtistFromPath ($path) {
    # Sample folder H:\Guns N' Roses\Appetite For Destruction\01 Welcome To The Jungle.flac
    $splitPath = $path.Split("\")
    # TODO this value needs changing dependant on folder being used
    return $splitPath[1]
}

# Main

# Get all the files
$musicFiles = Get-ChildItem -Path $MusicPath -Recurse

foreach ($musicFile in $musicFiles) {
    if ($musicFile.Extension -eq ".flac") {
        # DBG
        # Write-Host GetArtistFromPath -path $musicFile.FullName
        # Write-Host $musicFile.FullName $musicFile.DirectoryName

        $tags = $null

        # Get all the tags from the .flac file
        # From what I can tell this fails if the file has a [ or ] in it's name
        # so wrap in an exception, note it and continue on
        try {
            $tags = Get-Id3Tag($musicFile.FullName)
        }
        catch {
            Write-Host -ForegroundColor Red "Unable to get tags from " $musicFile.FullName
            continue
        }
        

        # Get the artist name
        $artistName = GetArtistFromPath -path $musicFile.FullName

        # Check the tags against the folder name
        if ($tags.FirstAlbumArtist -ne $artistName -and $tags.FirstArtist -ne $artistName) {
            Write-Host "The album " $musicFile " does not have correct metadata"
        }
        # break
    }
}
