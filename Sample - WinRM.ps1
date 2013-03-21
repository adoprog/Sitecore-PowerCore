Clear-Host

# Framework initialization
$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
$env:PSModulePath = $env:PSModulePath + ";$scriptRoot\Framework"

Import-Module Helpers
Import-Module DBUtils

# Main variables
$siteName = "PowerCoreSample"
$licensePath = "C:\license.xml"
$sourcePath = "C:\Sitecore 6.5.0 rev. 120706.zip"
$targetFolder = "C:\inetpub\wwwroot"
$serverName = $env:COMPUTERNAME
$sqlServerName = "$serverName\SQLEXPRESS"

# Used for WinRM
$targetServer = "192.168.1.101"
$username = "$targetServer\Administrator"
$password = "Password12345" 
$securePassword = $password | ConvertTo-SecureString -asPlainText -Force
$credentials = (New-Object System.Management.Automation.PSCredential($username, $securePassword))    

net use /delete \\$targetServer\C$ 2>$null 
net use \\$targetServer\C$ $password /USER:$username

Copy-Item $licensePath "\\$targetServer\C$\" -Verbose
Copy-Item $sourcePath "\\$targetServer\C$\" -Verbose

$commands = {
    param($siteName, $licensePath, $sourcePath, $targetFolder, $sqlServerName) 
    
	# Additional variables
	$packageFileName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
	$dataFolder = "$targetFolder\$packageFileName\Data"
	$websiteFolder = "$targetFolder\$packageFileName\Website"

    # Make sure previous instance of website is not running
    gps w3wp -ErrorAction SilentlyContinue | kill -verbose -Force

	# Main Script
	Unzip-Archive $sourcePath $targetFolder
	
	# Set connection strings 
	$databases = "core", "master", "web"
	foreach ($db in $databases)
	{
       	Set-ConnectionString "$websiteFolder\App_Config\ConnectionStrings.config" "$db" "user id=sa;password=Password12345;Data Source=$sqlServerName;Database=$siteName.$db"
	}
	
	Set-ConfigAttribute "$websiteFolder\web.config" "sitecore/sc.variable[@name='dataFolder']" "value" $dataFolder   

	Copy-Item $licensePath $dataFolder
	Create-AppPool $siteName "v2.0"
	Create-Site $siteName "$siteName.local"  "$targetFolder\$packageFileName"
	Add-HostFileContent "127.0.0.1" "$siteName.local"
}

Get-PSSession | Remove-PSSession
$session = New-PSSession -computerName $targetServer -credential $credentials 
Export-SourceModulesToSession $session -ModulePaths "$scriptRoot\Framework\ConfigUtils\ConfigUtils.psm1",
													"$scriptRoot\Framework\WebUtils\WebUtils.psm1",
													"$scriptRoot\Framework\DBUtils\DBUtils.psm1",
													"$scriptRoot\Framework\IISUtils\IISUtils.psm1",
													"$scriptRoot\Framework\FileUtils\FileUtils.psm1"

Invoke-Command -Session $session -Scriptblock $commands -ArgumentList $siteName, $licensePath, $sourcePath, $targetFolder, $sqlServerName