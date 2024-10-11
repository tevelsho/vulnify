param (
    [Alias("f")]
    [Parameter(Mandatory=$true)]
    [string]$Folder
)

# Functions for formatting logging messages
function Operation {
    param(
        [string]$msg,
        [int]$padding = 30
    )
    $formattedMsg = ("{0,-$padding}" -f $msg)
    Write-Host "[%] $formattedMsg" -ForegroundColor Cyan -BackgroundColor Black
}

function Error {
    param(
        [string]$msg,
        [int]$padding = 30
    )
    $formattedMsg = ("{0,-$padding}" -f $msg)
    Write-Host "[!] $formattedMsg" -ForegroundColor Red -BackgroundColor Black
}

function Success {
    param(
        [string]$msg,
        [int]$padding = 30
    )
    $formattedMsg = ("{0,-$padding}" -f $msg)
    Write-Host "[+] $formattedMsg" -ForegroundColor Green -BackgroundColor Black
}

# Function to check if the script is running with administrative privileges
function IsAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    
    # Returns True if the script is running with administrativ privileges, else return False
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to validate permitted files (.bin, .sys) in the specificed folder
function Validate-Files {
    param (
        [string]$Folder
    )

    Operation "Validating files in folder: $Folder"
    
    # Hash table to store the valid files
    $validFiles = @{
        'bin_files' = @()
        'sys_files' = @()
    }

    # Retrieves all files, loops, checks its extension and append it into their respective array
    Get-ChildItem -Path $Folder -File | ForEach-Object {
        $extension = $_.Extension.ToLower()
        if ($extension -eq ".bin") {
            $validFiles.bin_files += $_.FullName
        } elseif ($extension -eq ".sys") {
            $validFiles.sys_files += $_.FullName
        } else {
            Error "Invalid file type: $($_.Name)!"
        }
    }
    
    Success "Validation complete! Found [$($validFiles.bin_files.Count)] bin and [$($validFiles.sys_files.Count)] sys files.`n"
    return $validFiles
}

# Function to handle renaming, copying, and starting drivers based on the identity of the file
function Process-Files {
    param(
        [hashtable]$validFiles,
        [string]$folder
    )

    foreach ($binFile in $validFiles.bin_files) {
        $baseFile = [System.IO.Path]::GetFileNameWithoutExtension($binFile) # extracts file name w/o .bin ext
        $sysFile = Join-Path -Path $folder -ChildPath "$baseFile.sys" # construct full path of the .sys file
        
        Rename-Item -Path $binFile -NewName "$baseFile.sys" -ErrorAction Stop

        $destinationPath = Join-Path -Path "C:\Windows\System32\drivers" -ChildPath "$baseFile.sys"
        Copy-Item -Path $sysFile -Destination $destinationPath -ErrorAction Stop

        $serviceName = $baseFile
        $scCommand = "sc.exe create $serviceName binPath= `"$destinationPath`" type= kernel start= demand error= normal DisplayName= `"$serviceName Service`""
        Invoke-Expression $scCommand > $null 2>&1

        $startServiceCommand = "sc.exe start $serviceName"
        Invoke-Expression $startServiceCommand > $null 2>&1

        if ($LASTEXITCODE -ne 0) {
            Error "Vulnerable driver: [$serviceName] failed to start or was blocked."
        } else {
            Success "Vulnerable driver: [$serviceName] has started successfully."
        }
    }

    foreach ($sysFile in $validFiles.sys_files) {
        $baseFile = [System.IO.Path]::GetFileNameWithoutExtension($sysFile) # extracts file name w/o .bin ext

        $destinationPath = Join-Path -Path "C:\Windows\System32\drivers" -ChildPath "$baseFile.sys"
        Copy-Item -Path $sysFile -Destination $destinationPath -ErrorAction Stop

        bcdedit /set testsigning on > $null 2>&1 # allows unsigned drivers to load
        bcdedit /set nointegritychecks on > $null 2>&1 # allows vulnreable drivers to be loaded

        $serviceName = $baseFile
        $scCommand = "sc.exe create $serviceName binPath= `"$destinationPath`" type= kernel start= demand error= normal DisplayName= `"$serviceName Service`""
        Invoke-Expression $scCommand > $null 2>&1

        $startServiceCommand = "sc.exe start $serviceName"
        Invoke-Expression $startServiceCommand > $null 2>&1

        if ($LASTEXITCODE -ne 0) {
            Error "Vulnerable driver: [$serviceName] failed to start or was blocked."
        } else {
            Success "Vulnerable driver [$serviceName] has started successfully."
        }
    }
    Success "ALL drivers have been processed successfully!`n"
}

# MAIN EXECUTION
if (-not (IsAdmin)) {
    Start-Process -FilePath PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Folder `"$Folder`"" -Verb RunAs
    exit
}

# Call Validate-Files function to validate and return the valid files
$validFiles = Validate-Files -Folder $Folder

if (-not $validFiles.bin_files -and -not $validFiles.sys_files) {
    Error "No valid files found to process."
    exit 1
}

# Call Process-Files function to process valid files 
Process-Files -validFiles $validFiles -folder $Folder

# DEBUGGING - Prevent the terminal from closing immediately
Read-Host -Prompt "Press Enter to close:"
