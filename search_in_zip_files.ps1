param(
    [parameter(position=0,mandatory=$true)][string] $archivePath,
    [parameter(position=1,mandatory=$true)][string] $pattern
);

# import .NET 4.5 compression utilities
Add-Type -As System.IO.Compression.FileSystem;

# open archive for reading
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath);
try
{
    # enumerate all entries in the archive, which includes both files and directories
    foreach($archiveEntry in $archive.Entries)
    {
        # if the entry is not a directory (which ends with /)
        if($archiveEntry.FullName -notmatch '/$')
        {
            # get temporary file -- note that this will also create the file
            $tempFile = [System.IO.Path]::GetTempFileName();
            try
            {
                # extract to file system
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($archiveEntry, $tempFile, $true);

                # create PowerShell backslash-friendly path from ZIP path with forward slashes
                $windowsStyleArchiveEntryName = $archiveEntry.FullName.Replace('/', '\');
                # run selection
                Get-ChildItem $tempFile | Select-String -pattern "${pattern}" | Select-Object @{Name="Filename";Expression={$windowsStyleArchiveEntryName}}, @{Name="Path";Expression={Join-Path $archivePath (Split-Path $windowsStyleArchiveEntryName -Parent)}}, Matches, LineNumber
            }
            finally
            {
                Remove-Item $tempFile;
            }
        }
    }
}
finally
{
    # release archive object to prevent leaking resources
    $archive.Dispose();
}