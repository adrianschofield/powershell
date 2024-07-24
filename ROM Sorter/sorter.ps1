# This script gathers ROMs from the Sanni micro SD card and organises them into a library

# Globals
$usbDrive = "f:\\"
$destRomLibrary = "D:\\temp\\"
$libraryFolder = "ROM_Library"
$libraryPath = $destRomLibrary + $libraryFolder

# For the most part the actual roms have the same file extension as the directory
# they are found in. However some don't so I am creating a hashtable to match folder
# names to extensions

# TODO Add all relevant extensions (not sure how I find this out)
$extensions = @{    MD = ".md";
                    SNES = ".sfc";
                    GB = ".gb";
                    GBA = ".gba";
                    N64 = ".z64";
                    NES = ".nes"}

# Functions

# Main

# Get a list of folders from our USB drive where the SD card is mounted
$folders = Get-ChildItem -Path $usbDrive -Directory

if ($folders.Count -gt 0) {
    if (!(Test-Path -Path $libraryPath)) {
        # Set up the library folder
        New-Item -Path $destRomLibrary -Name $libraryFolder -ItemType Directory
    }
}

# Go through each of the folders and pull out the ROM files
foreach ($folder in $folders) {
    Write-Host $folder.Name

    # First create the destination folder for each system
    New-Item -Path $libraryPath -Name $folder.Name -ItemType Directory

    # Now find all the relevant ROM files
    $romFilePathSpec = $folder.FullName + "\\*" + $extensions[$folder.Name]
    $romFiles = Get-ChildItem -Path $romFilePathSpec -Recurse

    $destPath = $libraryPath + "\\" + $folder.Name
    foreach ($romFile in $romFiles) {
        # DBG
        Write-Host $romFile.Name
        # Copy the ROM file to the library
        Copy-Item -Path $romFile.FullName -Destination $destPath
    }
}