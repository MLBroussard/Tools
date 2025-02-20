function Update-PackageFolder {
    param (
        [string]$Update,
        [string]$DestDir
    )

    if (!(Test-Path -Path $Update)) {
        Write-Output "Error: Source directory does not exist: $Update"
        return
    }
    if (!(Test-Path -Path $DestDir)) {
        Write-Output "Error: Destination directory does not exist: $DestDir"
        return
    }

    # Extract version number from Update folder name
    if ($Update -match 'package_([\d\.]+)') {
        $version = $matches[1]
        $releaseFilePath = Join-Path -Path $DestDir -ChildPath "RELEASE.txt"
        Set-Content -Path $releaseFilePath -Value $version
        Write-Output "Version $version saved to RELEASE.txt"
    } else {
        Write-Output "Error: Source directory name does not contain a version number"
        return
    }

    # Get lists of files and directories (excluding directories)
    $sourceFiles = Get-ChildItem -Path $Update -Recurse -File
    $sourceDirs = Get-ChildItem -Path $Update -Recurse -Directory
    $destFiles = Get-ChildItem -Path $DestDir -Recurse -File

    # Create a hashtable of destination file hashes
    $destFileHashes = @{}
    foreach ($file in $destFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($DestDir, $file.FullName)
        $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
        $destFileHashes[$relativePath] = $hash.Hash
    }

    # Ensure all source directories exist in the destination
    foreach ($dir in $sourceDirs) {
        $relativePath = [System.IO.Path]::GetRelativePath($Update, $dir.FullName)
        $targetDir = Join-Path -Path $DestDir -ChildPath $relativePath
        if (!(Test-Path -Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
    }

    # Compare and copy files
    foreach ($file in $sourceFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($Update, $file.FullName)
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

Update-PackageFolder -Update '.\package_1.2134.0' -DestDir '.\build'