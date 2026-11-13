$os = "undefined"
$actCommand = "act"
$dockerCommand = "docker"

function DefineOS {
	$osDescription = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
	if ($osDescription -like "*windows*") {
		return "windows"
	}
	elseif (($osDescription -like "*mac*") -or ($osDescription -like "*darwin*")) {
		return "macos"
	}
	else {
		return "linux"
	}
}

function Request-AdminPrivileges {
	param([string]$scriptPath)

	if (($os -eq "macos") -or ($os -eq "linux")) {
		$isRoot = (id -u) -eq 0
        
		if (-not $isRoot) {
			$allArguments = $MyInvocation.Line.Replace($MyInvocation.InvocationName, '').Trim()
            
			if ($scriptPath) {
				Write-Warning "Root privileges required. Asking for sudo."
				$command = "sudo pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $allArguments"
				Invoke-Expression $command
				exit
			}
			else {
				Write-Error "Cannot elevate: Script must be saved to a file."
				exit
			}
		}
	}
}

function RunAsAdmin {
	if ($os -eq "windows") {
		$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
		$isAdmin = (New-Object Security.Principal.WindowsPrincipal $currentUser).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	
		if (-not $isAdmin) {
			Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
			exit
		}
	}
	elseif (($os -eq "macos") -or ($os -eq "linux")) {
		$isRoot = (id -u) -eq 0
        
		if (-not $isRoot) {
			Request-AdminPrivileges -scriptPath $PSCommandPath
			exit
		}
	}
}

$os = DefineOS
RunAsAdmin
Write-Host $os

function Test-CommandExists {
	param([string]$cmdname)
	return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

function Test-Network {
	param([string]$HostName = "www.google.com")
    
	try {
		if ($os -eq "windows") {
			$connectionResult = Test-NetConnection -ComputerName $HostName
			return $connectionResult
		}
		else {
			[System.Net.Dns]::GetHostEntry($HostName) | Out-Null
				
			if ($os -eq "macos") {
				ping -c 1 -t 5 $HostName 2>&1 | Out-Null
			}
			elseif ($os -eq "linux") {
				ping -c 1 -W 5 $HostName 2>&1 | Out-Null
			}
				
			return ($LASTEXITCODE -eq 0)
		}
	}
	catch {
		return $false
	}
}

if (-not (Test-Network)) {
	Write-Host "An Internet connection is required." -ForegroundColor Red
	Pause
	exit
}

function Install-Act-Windows {
	if (Test-CommandExists -cmdname 'winget') {
		winget install -e --id nektos.act --disable-interactivity --silent --accept-package-agreements --accept-source-agreements
	}

	if (-not (Test-CommandExists -cmdname $actCommand)) {
		if (Test-CommandExists -cmdname 'choco') {
			choco upgrade act-cli -y
		}
	}

	if (-not (Test-CommandExists -cmdname $actCommand)) {
		Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
		#$env:PATH += ";C:\ProgramData\chocolatey\bin;"
		if (Test-CommandExists -cmdname 'choco') {
			choco upgrade act-cli -y
		}
	}
}

function Install-Act-MacOS {
	$actInstalled = $false

	if (Test-CommandExists -cmdname 'brew') {
		$originalUser = $env:SUDO_USER
		if (-not $originalUser) {
			$originalUser = (Get-ChildItem /Users | Where-Object { $_.Name -ne 'root' -and $_.Name -ne 'Shared' } | Select-Object -First 1).Name
		}
		
		sudo -u $originalUser brew install act
		
		if (Test-CommandExists -cmdname 'act') {
			$actInstalled = $true
		}
	}

	if (-not $actInstalled -and (Test-CommandExists -cmdname 'port')) {
		#Not tested
		port install act
		if (Test-CommandExists -cmdname $actCommand) {
			$actInstalled = $true
		}
	}

	if (-not $actInstalled) {
		#Not tested
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		if (Test-CommandExists -cmdname 'brew') {
			brew install act
			if (Test-CommandExists -cmdname $actCommand) {
				$actInstalled = $true
			}
		}
	}
}

function Install-Act-Linux {
	curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
	sudo cp  ./bin/act /bin
}


if (-not (Test-CommandExists -cmdname $actCommand)) {
	Write-Host "'$actCommand' isn't installed."

	if ($os -eq "windows") {
		Install-Act-Windows
	}
	elseif ($os -eq "macos") {
		Install-Act-MacOS
	}
	elseif ($os -eq "linux") {
		Install-Act-Linux
	}

	if (-not (Test-CommandExists -cmdname $actCommand)) {
		Write-Host "Couldn't install '$actCommand'" -ForegroundColor Red
		Pause
		exit
	}
}

function Install-Docker-Windows {
	try {
		# Required for both WSL and Docker
		Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All
	}
	catch {
		Write-Host "Couln't Enable Windows Feature: 'VirtualMachinePlatform'" -ForegroundColor Red
		Write-Host $_ -ForegroundColor Red
		Pause
		exit
	}
	wsl --install --no-distribution
	choco upgrade -y docker-desktop
}

function Install-Docker-MacOS {
	#NOT TESTED
	Write-Host "Installing Docker Desktop for macOS..." -ForegroundColor Yellow
    
	if (Test-CommandExists -cmdname 'brew') {
		Write-Host "Installing Docker via Homebrew..." -ForegroundColor Yellow
		brew install --cask docker
        
		Write-Host "Docker Desktop installed. Please:" -ForegroundColor Yellow
		Write-Host "1. Open Docker Desktop from Applications" -ForegroundColor Cyan
		Write-Host "2. Follow the setup instructions" -ForegroundColor Cyan
		Write-Host "3. Start Docker Desktop" -ForegroundColor Cyan
        
		return $true
	}
	else {
		Write-Host "Please install Docker Desktop manually:" -ForegroundColor Yellow
		Write-Host "Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Cyan
		return $false
	}
}

function Install-Docker-Linux {
	Write-Host "Installing Docker Desktop for linux..." -ForegroundColor Yellow
	curl -fsSL https://get.docker.com -o get-docker.sh
	sh get-docker.sh
}

if (-not (Test-CommandExists -cmdname $dockerCommand)) {
	Write-Host "$dockerCommand isn't installed."

	if ($os -eq "windows") {
		Install-Docker-Windows
	}
	elseif ($os -eq "macos") {
		Install-Docker-MacOS
	}
	elseif ($os -eq "linux") {
		Install-Docker-Linux
	}

	if (-not (Test-CommandExists -cmdname $dockerCommand)) {
		Write-Host "Couldnt install '$dockerCommand'" -ForegroundColor Red
		Pause
		exit
	}
}

if ($os -eq "windows") {
	try {
		Start-Process -FilePath "C:\Program Files\Docker\Docker\Docker Desktop.exe"
		Start-Sleep -Seconds 10
	}
	catch {
		Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
	}
}
elseif ($os -eq "macos") {
	Write-Host "START DOCKER: NOT IMPLEMENTED ON MACOS" -ForegroundColor Red
	# open /Applications/Docker.app
}
elseif ($os -eq "linux") {
	Write-Host "Starting docker..." -ForegroundColor Magenta
	sudo systemctl start docker
}

Pause