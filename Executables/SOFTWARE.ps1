param (
	[switch]$Chrome,
	[switch]$Brave,
	[switch]$Firefox
)

# ----------------------------------------------------------------------------------------------------------- #
# Software is no longer installed with a package manager anymore to be as fast and as reliable as possible.   #
# ----------------------------------------------------------------------------------------------------------- #

$msiArgs = "/qn /quiet /norestart ALLUSERS=1 REBOOT=ReallySuppress"
$arm = ((Get-CimInstance -Class Win32_ComputerSystem).SystemType -match 'ARM64') -or ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64')
$armString = ('x64', 'arm64')[$arm]

# Create temporary directory
$tempDir = Join-Path -Path $([System.IO.Path]::GetTempPath()) -ChildPath $([System.Guid]::NewGuid())
New-Item $tempDir -ItemType Directory -Force | Out-Null
Push-Location $tempDir

# Brave
if ($Brave) {
	Write-Output "Downloading Brave..."
	& curl.exe -LSs "https://laptop-updates.brave.com/latest/winx64" -o "$tempDir\BraveSetup.exe"
	if (!$?) {
		Write-Error "Downloading Brave failed."
		exit 1
	}

	Write-Output "Installing Brave..."
	& "$tempDir\BraveSetup.exe" /silent /install 2>&1 | Out-Null

	do {
		$processesFound = Get-Process | Where-Object { "BraveSetup" -contains $_.Name } | Select-Object -ExpandProperty Name
		if ($processesFound) {
			Write-Output "Still running BraveSetup."
			Start-Sleep -Seconds 2
		} else {
			Remove-Item "$tempDir" -ErrorAction SilentlyContinue -Force -Recurse
		}
	} until (!$processesFound)

	Stop-Process -Name "brave" -Force -ErrorAction SilentlyContinue
	exit
}

# Firefox
if ($Firefox) {
	if ($arm) {
		$firefoxArch = 'win64-aarch64'
	} else {
		$firefoxArch = 'win64'
	}

	Write-Output "Downloading Firefox..."
	& curl.exe -LSs "https://download.mozilla.org/?product=firefox-latest-ssl&os=$firefoxArch&lang=en-US" -o "$tempDir\firefox.exe"
	Write-Output "Installing Firefox..."
	Start-Process -FilePath "$tempDir\firefox.exe" -WindowStyle Hidden -ArgumentList '/S /ALLUSERS=1' -Wait 2>&1 | Out-Null
	exit
}

# Chrome
if ($Chrome) {
	Write-Output "Downloading Google Chrome..."
	& curl.exe -LSs "https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi" -o "$tempDir\chrome.msi"
	Write-Output "Installing Google Chrome..."
	Start-Process -FilePath "$tempDir\chrome.msi" -WindowStyle Hidden -ArgumentList '/qn' -Wait 2>&1 | Out-Null
	exit
}

#####################
##    Utilities    ##
#####################

# 7-Zip
$website = 'https://7-zip.org/'
$download = $website + ((Invoke-WebRequest $website -UseBasicParsing).Links.href | Where-Object { $_ -like "a/7z*-$armString.exe" })
Write-Output "Downloading 7-Zip..."
& curl.exe -LSs $download -o "$tempDir\7zip.exe"
Write-Output "Installing 7-Zip..."
Start-Process -FilePath "$tempDir\7zip.exe" -WindowStyle Hidden -ArgumentList '/S' -Wait 2>&1 | Out-Null

# Remove temporary directory
Pop-Location
Remove-Item -Path $tempDir -Force -Recurse *>$null
