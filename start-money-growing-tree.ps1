# Ensure that Docker Desktop is running
if (-not (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Desktop is not running. Please start Docker Desktop and try again."
    exit 1
}

# Define the folders
$folders = @("data-aggregator", "trading-bot", "money-growing-tree-frontend", "mgt-trading-algorithms")

# Define the network name
$networkName = "my_network"

# Create a Docker network if it doesn't already exist
if (-not (docker network ls --format "{{.Name}}" | Where-Object { $_ -eq $networkName })) {
    Write-Host "Creating Docker network: $networkName"
    docker network create $networkName
}

# Function to update and restart a single folder
function Update-And-Restart {
    param (
        [string]$folder
    )

    # Define image and container names
    $imageName = "$folder-image"
    $containerName = "$folder-container"

    # Stop and remove any existing container with the same name
    if (docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq $containerName }) {
        Write-Host "Stopping and removing existing container: $containerName"
        docker stop $containerName
        docker rm $containerName
    }

    # Delete pre-existing Docker images containing the folder's name
    $existingImages = docker images --format "{{.Repository}}" | Where-Object { $_ -like "$folder*" }
    if ($existingImages) {
        foreach ($image in $existingImages) {
            Write-Host "Removing existing image: $image"
            docker rmi -f $image
        }
    }

    # Navigate to the folder
    $folderPath = "../$folder"
    if (-not (Test-Path -Path $folderPath)) {
        Write-Host "Folder $folder does not exist. Skipping..."
        return
    }

    Push-Location $folderPath

    # Build the Docker image
    Write-Host "Building Docker image for $folder..."
    docker build -t $imageName .

    # Return to the original directory
    Pop-Location

    # Extract the exposed port from the Dockerfile
    $dockerfile = Join-Path $folderPath "Dockerfile"
    if (Test-Path -Path $dockerfile) {
        $exposedPort = Select-String -Path $dockerfile -Pattern "EXPOSE (\d+)" | ForEach-Object { $_.Matches[0].Groups[1].Value }

        if ($exposedPort) {
            Write-Host "Starting container $containerName with port $exposedPort on network $networkName..."
            docker run -d --name $containerName --network $networkName -p "${exposedPort}:${exposedPort}" $imageName
        } else {
            Write-Host "No EXPOSE instruction found in $dockerfile. Skipping container startup for $folder."
        }
    } else {
        Write-Host "Dockerfile not found in $folder. Skipping container startup."
    }
}

# Function to clean up dangling images after all updates are done
function Cleanup-DanglingImages {
    Write-Host "Cleaning up dangling images..."
    
    # Prune dangling images
    docker image prune -f  # Use '-f' to force without confirmation
    
    # Optionally, you can also prune unused images, containers, networks, etc.
}

# Display menu for user selection
Write-Host "Choose an option:" -ForegroundColor Green
Write-Host "1. Update All" -ForegroundColor Cyan
Write-Host "2. Update data-aggregator" -ForegroundColor Cyan
Write-Host "3. Update trading-bot" -ForegroundColor Cyan
Write-Host "4. Update money-growing-tree-frontend" -ForegroundColor Cyan
Write-Host "5. Update mgt-trading-algorithms" -ForegroundColor Cyan

$choice = Read-Host "Enter your choice (1-5)"

switch ($choice) {
    "1" {
        Write-Host "Updating all folders..." -ForegroundColor Yellow
        foreach ($folder in $folders) {
            Update-And-Restart -folder $folder
        }
        
        # Clean up dangling images after updating all containers
        Cleanup-DanglingImages
    }
    "2" {
        Update-And-Restart -folder "data-aggregator"
        
        # Clean up dangling images after updating this specific folder
        Cleanup-DanglingImages
    }
    "3" {
        Update-And-Restart -folder "trading-bot"
        
        # Clean up dangling images after updating this specific folder
        Cleanup-DanglingImages
    }
    "4" {
        Update-And-Restart -folder "money-growing-tree-frontend"
        
        # Clean up dangling images after updating this specific folder
        Cleanup-DanglingImages
    }
    "5" {
        Update-And-Restart -folder "mgt-trading-algorithms"
        
        # Clean up dangling images after updating this specific folder
        Cleanup-DanglingImages
    }
    default {
        Write-Host "Invalid choice. Please run the script again and choose a valid option." -ForegroundColor Red
    }
}

Write-Host "All tasks completed." -ForegroundColor Green

