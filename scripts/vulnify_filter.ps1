param (
    [Alias("h")]
    [Parameter(Mandatory=$false)]
    [switch]$Help,

    [Alias("a")]
    [Parameter(Mandatory=$false)]
    [switch]$All,

    [Alias("d")]
    [Parameter(Mandatory=$false)]
    [string]$Year,    
    
    [Alias("dd")]
    [Parameter(Mandatory=$false)]
    [string]$Date,            

    [Alias("os")]
    [Parameter(Mandatory=$false)]
    [string]$OperatingSystem, 

    [Alias("u")]
    [Parameter(Mandatory=$false)]
    [string]$UseCase       
)

# Check if no parameters were passed
if ($PSBoundParameters.Count -eq 0) {
    $Help = $true
}

# Display help information if --help is invoked
if ($Help) {
   Write-Host @"
Usage: ./vulnify.ps1 [options...] <input folder>

COMMON OPTIONS

  -f  <path>    : Folder containing specific vulnerable drivers to test (.bin/.sys)
  -d  <year>    : Filter by creation year
  -dd <date>    : Filter by full creation date (yy-mm-date)
  -os <os>      : Filter by specific operating system
  -u  <usecase> : Filter by exploit usecase
  -s            : Stop all vulnerable driver services immediately after testing
  -r            : Stop and remove all vulnerable drivers from the system
  -vv           : Verbose output

OTHER OPTIONS

  --help        : Displays this help page

EXAMPLES

  ./vulnify.ps1 -v -a
  ./vulnify.ps1 -v -d "2023" -os "Windows 10"
  ./vulnify.ps1 -v -dd "2024-06-20" -u "Elevate privileges"
  ./vulnify.ps1 -f "C:\Users\admin\Documents\vulnerable\drivers\" -r

"@
    exit
}

# Functions for formatting logging messages
function Option {
    param(
        [string]$msg,
        [int]$padding = 30
    )
    $formattedMsg = ("{0,-$padding}" -f $msg)
    Write-Host "[>] $formattedMsg" -ForegroundColor Yellow -BackgroundColor Black
}

function Operation {
    param(
        [string]$msg,
        [int]$padding = 30
    )
    $formattedMsg = ("{0,-$padding}" -f $msg)
    Write-Host "[%] $formattedMsg" -ForegroundColor Blue -BackgroundColor Black
}

function Info {
    param(
        [string]$msg,
        [int]$padding = 30
    )
    $formattedMsg = ("{0,-$padding}" -f $msg)
    Write-Host "[*] $formattedMsg" -ForegroundColor White 
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

# API endpoint, returns driver information in JSON
$url = "https://www.loldrivers.io/api/drivers.json"

# Base URL for downloading drivers
$url_download = "https://github.com/magicsword-io/LOLDrivers/raw/main/drivers/"

# Initialize an array to store the MD5 hashes of the drivers
$md5Hashes = @()

# Get the current directory (ensure it's initialized before usage)
$currentDirectory = Get-Location

# Store the root path directly to ensure it's in the root directory
$rootDirectory = [System.IO.Directory]::GetParent($currentDirectory.Path).FullName

# Set the download folder path to the root directory
$downloadFolder = Join-Path -Path $rootDirectory -ChildPath "vulnerable_LOTL_drivers"

# Function to determine if a value meets the filter criteria
function Check-Filter {
    param (
        $value,
        $filterValue
    )

    # Checks if the filter value is empty, if so, no filtering will be applied, return True
    if ([string]::IsNullOrEmpty($filterValue)) {
        return $true
    }

    # Checks if the value contains the filter value
    return "$value" -like "*$filterValue*"
}

# Function to download drivers based on MD5 hashes
function Download-Drivers {
    param (
        [string[]]$md5Hashes,
        [string]$downloadFolder
    )

    # Create folder if it does not exist
    if (-not (Test-Path $downloadFolder)) {
        New-Item -ItemType Directory -Path $downloadFolder
    }

    # Clear existing files in the folder
    Get-ChildItem -Path $downloadFolder -File | Remove-Item -Force

    foreach ($md5 in $md5Hashes) {
        # Construct the full download URL by appending the hash and .bin
        $downloadUrl = "$url_download$md5.bin"
        $outputPath = Join-Path -Path $downloadFolder -ChildPath "$md5.bin"

        # Download the driver files from LOTL
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath
    }
}

try {
    # HTTP GET request to the API to retrieve the data, returned in JSON
    $response = Invoke-WebRequest -Uri $url -Method Get

    # Convert the content from JSON to a PowerShell hashtable
    $jsonContent = $response.Content | ConvertFrom-Json -AsHashTable

    if ($jsonContent -is [Array]) {
        if ($All) {
            # When -a is specified, get all MD5 hashes from the API response
            foreach ($item in $jsonContent) {
                if ($item['Verified'] -eq "TRUE") {
                    # Retrieve vulnerable driver MD5 hash
                    if ($item['KnownVulnerableSamples']) {
                        $tags = $item['Tags'][0]
                        $creationDate = $item['Created']

                        foreach ($sample in $item['KnownVulnerableSamples']) {
                            if ($sample['MD5']) {
                            $md5_hash = $sample['MD5']
                            $operatingSystem = $item['Commands']['OperatingSystem']
                            $useCases = $item['Commands']['Usecase']
                            
                            # Define fixed column widths
                            $formatString = "{0,-25} | {1,-15} | {2,-20} | {3,-35} | {4,-32}"

                            # Loop through your items and output the formatted information
                            Info ($formatString -f $tags, 
                                            $creationDate, 
                                            $OperatingSystem, 
                                            $useCases, 
                                            $md5_hash)

                            $md5Hashes += $md5_hash
                            $matchCount++
                            }
                        }
                    } else {
                        Write-Output "  No KnownVulnerableSamples found for item: $($item['Id'])"
                    }
                }

            }
            Write-Output "Total MD5 hashes collected: $($md5Hashes.Count)"
            # Optionally, you could proceed with downloading or other actions here
        } else {
            $matchCount = 0
            foreach ($item in $jsonContent) {
                # Check if 'Created' field matches the filter, based on $Date passed by the user
                if (Check-Filter $item['Created'] $Date) {
                    $commands = $item['Commands']

                    # Apply filtering based on user inputs for OS, Privileges, and Use Case
                    if (Check-Filter $commands['OperatingSystem'] $OperatingSystem -and Check-Filter $commands['Usecase'] $UseCase) {

                        # Retrieve vulnerable driver MD5 hash
                        if ($item['KnownVulnerableSamples']) {
                            $tags = $item['Tags'][0]
                            $creationDate = $item['Created']


                            foreach ($sample in $item['KnownVulnerableSamples']) {
                                if ($sample['MD5']) {
                                $md5_hash = $sample['MD5']
                                $operatingSystem = $item['Commands']['OperatingSystem']
                                $useCases = $item['Commands']['Usecase']
                                
                                # Define fixed column widths
                                $formatString = "{0,-25} | {1,-15} | {2,-20} | {3,-35} | {4,-32}"

                                # Loop through your items and output the formatted information
                                Info ($formatString -f $tags, 
                                                $creationDate, 
                                                $OperatingSystem, 
                                                $useCases, 
                                                $md5_hash)

                                $md5Hashes += $md5_hash
                                $matchCount++
                                }
                            }
                        } else {
                            Write-Output "  No KnownVulnerableSamples found for item: $($item['Id'])"
                        }
                    }
                }
            }
            Write-Output " "
            Write-Output "Total matches found: $matchCount"
        }

    # Call the Download-Drivers function with collected MD5 hashes
    if ($md5Hashes.Count -gt 0) {
        Download-Drivers -md5Hashes $md5Hashes -downloadFolder $downloadFolder
    } else {
        Write-Output "No MD5 hashes to download."
    }
    
    } else {
        Write-Output "Response is not an array. Actual content type: $($jsonContent.GetType().Name)"
        Write-Output "First few keys of the response:"
        $jsonContent.Keys | Select-Object -First 5 | ForEach-Object { Write-Output "  $_" }
    }
} catch {
    Write-Output "An error occurred while fetching or processing the API data:"
    Write-Output $_.Exception.Message
    Write-Output "Stack Trace:"
    Write-Output $_.ScriptStackTrace
}

# Call driver_loader.ps1
& "$PSScriptRoot\driver_loader.ps1" -Folder $($downloadFolder)

<#
./driver_filter.ps1 -a 
./driver_filter -dd "2024-06-20" -u "Elevate privileges"
#>