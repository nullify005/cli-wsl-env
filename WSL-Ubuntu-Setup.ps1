param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("install", "update")]
    [string]$Action,

    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [string]$User = $env:USERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$InstallLocation = "C:\WSL\$Name",

    [Parameter(Mandatory=$false)]
    [string]$PackageLocation = "C:\WSL\.packages",

    [Parameter(Mandatory=$false)]
    [string]$DistroRootfs = "https://mirror.aarnet.edu.au/pub/ubuntu/releases/24.04/ubuntu-24.04.2-wsl-amd64.wsl",

    [Parameter(Mandatory=$false)]
    [string]$DistroRootfsHash = "5D1EEA52103166F1C460DC012ED325C6EB31D2CE16EF6A00FFDFDA8E99E12F43"
)

# Function to check if WSL distribution exists
function Test-WSLDistribution {
    param([string]$Name)
    
    $existingDistros = wsl --list --quiet
    return $existingDistros -contains $Name
}

# Function to remove existing WSL distribution
function Remove-WSLDistribution {
    param([string]$Name)
    
    Write-Host "Found existing distribution '$Name'. Deleting..." -ForegroundColor Yellow
    wsl --unregister $Name
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted distribution '$Name'" -ForegroundColor Green
        return $true
    } else {
        Write-Error "Failed to delete distribution '$Name'"
        return $false
    }
}

# Function to create required directories
function New-WSLDirectories {
    param(
        [string]$InstallPath,
        [string]$PackagePath
    )
    
    Write-Host "Creating installation directory: $InstallPath" -ForegroundColor Yellow
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }

    Write-Host "Creating package directory: $PackagePath" -ForegroundColor Yellow
    if (-not (Test-Path $PackagePath)) {
        New-Item -ItemType Directory -Path $PackagePath -Force | Out-Null
    }
}

# Function to download and verify rootfs image
function Get-RootfsImage {
    param(
        [string]$DownloadUrl,
        [string]$DownloadPath,
        [string]$ExpectedHash
    )
    
    if (Test-Path $DownloadPath) {
        Write-Host "Located rootfs image" -ForegroundColor Yellow
    } else {
        Write-Host "Downloading rootfs image..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $DownloadUrl -OutFile $DownloadPath -UseBasicParsing
            Write-Host "Download completed successfully" -ForegroundColor Green
        } catch {
            Write-Error "Failed to download rootfs image: $_"
            return $false
        }
    }
    
    # Verify hash
    $downloadHash = (Get-FileHash $DownloadPath).Hash
    if ($downloadHash -ne $ExpectedHash) {
        Write-Error "Hash checksum failed. Expected: $ExpectedHash Got: $downloadHash"
        return $false
    }
    
    Write-Host "Rootfs image verified successfully" -ForegroundColor Green
    return $true
}

# Function to import WSL distribution
function Import-WSLDistribution {
    param(
        [string]$Name,
        [string]$InstallPath,
        [string]$RootfsPath
    )
    
    Write-Host "Installing rootfs as '$Name'..." -ForegroundColor Yellow
    wsl --import $Name $InstallPath $RootfsPath

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully installed rootfs as '$Name'" -ForegroundColor Green
        return $true
    } else {
        Write-Error "Failed to install rootfs"
        return $false
    }
}

# Function to run ansible setup
function Invoke-AnsibleSetup {
    param(
        [string]$Name,
        [string]$User
    )
    
    Write-Host "Running ansible setup..." -ForegroundColor Yellow
    
    # Update system packages
    wsl -d $Name --user root -- bash -c "apt update && apt upgrade -y"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update system packages"
        return $false
    }
    
    # Install ansible if not present
    wsl -d $Name --user root -- bash -c "apt-get -y install ansible"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install ansible"
        return $false
    }
    
    # Run ansible setup
    wsl -d $Name --user root -- bash -c "cd ansible; ./run.sh $User"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to run ansible setup"
        return $false
    }
    
    Write-Host "Ansible setup completed successfully" -ForegroundColor Green
    return $true
}

# Function to finalize WSL setup
function Set-WSLConfiguration {
    param(
        [string]$Name,
        [string]$User
    )
    
    Write-Host "Finalizing WSL configuration..." -ForegroundColor Yellow
    wsl --manage $Name --set-default-user $User
    wsl --terminate $Name
    wsl --shutdown
    wsl --manage $Name --set-sparse true
    
    Write-Host "WSL configuration completed" -ForegroundColor Green
}

# Function to perform full installation
function Install-WSLDistribution {
    Write-Host "Starting WSL installation for: $Name" -ForegroundColor Green
    
    # Check if distribution exists and remove it
    Write-Host "Checking if WSL distribution '$Name' exists..." -ForegroundColor Yellow
    if (Test-WSLDistribution -Name $Name) {
        if (-not (Remove-WSLDistribution -Name $Name)) {
            exit 1
        }
    } else {
        Write-Host "Distribution '$Name' does not exist. Proceeding with installation." -ForegroundColor Yellow
    }
    
    # Create directories
    New-WSLDirectories -InstallPath $InstallLocation -PackagePath $PackageLocation
    
    # Download and verify rootfs
    $rootFsFilename = Split-Path $DistroRootfs -Leaf
    $downloadPath = "$PackageLocation\$rootFsFilename"
    
    if (-not (Get-RootfsImage -DownloadUrl $DistroRootfs -DownloadPath $downloadPath -ExpectedHash $DistroRootfsHash)) {
        exit 1
    }
    
    # Import distribution
    if (-not (Import-WSLDistribution -Name $Name -InstallPath $InstallLocation -RootfsPath $downloadPath)) {
        exit 1
    }
    
    # Run ansible setup
    if (-not (Invoke-AnsibleSetup -Name $Name -User $User)) {
        exit 1
    }
    
    # Finalize configuration
    Set-WSLConfiguration -Name $Name -User $User
    
    Write-Host "" -ForegroundColor Green
    Write-Host "Installation completed successfully!" -ForegroundColor Green
    Write-Host "You can now access your WSL distribution with: wsl -d $Name" -ForegroundColor Green
}

# Function to update existing distribution
function Update-WSLDistribution {
    Write-Host "Starting WSL update for: $Name" -ForegroundColor Green
    
    # Check if distribution exists
    if (-not (Test-WSLDistribution -Name $Name)) {
        Write-Error "WSL distribution '$Name' does not exist. Use 'install' action to create it first."
        exit 1
    }
    
    # Run ansible setup only
    if (-not (Invoke-AnsibleSetup -Name $Name -User $User)) {
        exit 1
    }
    
    # Finalize configuration
    Set-WSLConfiguration -Name $Name -User $User
    
    Write-Host "" -ForegroundColor Green
    Write-Host "Update completed successfully!" -ForegroundColor Green
    Write-Host "You can access your updated WSL distribution with: wsl -d $Name" -ForegroundColor Green
}

# Main switch statement
switch ($Action.ToLower()) {
    "install" {
        Install-WSLDistribution
    }
    "update" {
        Update-WSLDistribution
    }
    default {
        Write-Error "Invalid action: $Action. Use 'install' or 'update'"
        exit 1
    }
}
