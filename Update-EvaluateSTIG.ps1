function Update-PackageFolder {
    param (
        [string]$SourceDir,
        [string]$DestDir
    )

    if (!(Test-Path -Path $SourceDir)) {
        Write-Output "Error: Source directory does not exist: $SourceDir"
        return
    }
    if (!(Test-Path -Path $DestDir)) {
        Write-Output "Error: Destination directory does not exist: $DestDir"
        return
    }

    # Get lists of files (excluding directories)
    $sourceFiles = Get-ChildItem -Path $SourceDir -Recurse -File
    $destFiles = Get-ChildItem -Path $DestDir -Recurse -File

    # Create a hashtable of destination file hashes
    $destFileHashes = @{}
    foreach ($file in $destFiles) {
        $relativePath = $file.FullName.Replace($DestDir, '')
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $destFileHashes[$relativePath] = $hash.Hash
    }

    # Compare and copy files
    foreach ($file in $sourceFiles) {
        $relativePath = $file.FullName.Replace($SourceDir, '')
        $targetPath = Join-Path -Path $DestDir -ChildPath $relativePath
        $targetDir = Split-Path -Path $targetPath -Parent

        # Ensure target directories exist
        if (!(Test-Path -Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # If file does not exist in destination, copy it
        if (-not $destFileHashes.ContainsKey($relativePath)) {
            Copy-Item -Path $file.FullName -Destination $targetPath -Force
            Write-Output "New file copied: $relativePath"
        }
        else {
            # Get source file hash
            $sourceHash = Get-FileHash -Path $file.FullName -Algorithm SHA256

            # If hashes do not match, update the file
            if ($sourceHash.Hash -ne $destFileHashes[$relativePath]) {
                Copy-Item -Path $file.FullName -Destination $targetPath -Force
                Write-Output "Updated file copied: $relativePath"
            }
        }
    }

    Write-Output "Update process completed."
}
