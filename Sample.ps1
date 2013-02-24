Clear-Host

# Framework initialization
$scriptRoot = Split-Path (Resolve-Path $myInvocation.MyCommand.Path)
$env:PSModulePath = $env:PSModulePath + ";$scriptRoot\Framework"

Import-Module WebUtils
Import-Module ConfigUtils
Import-Module DBUtils
Import-Module IISUtils
Import-Module FileUtils

# Main variables
$siteName = "PowerCoreSample"
$licensePath = "C:\license.xml"
$sourcePath = "C:\Sitecore 6.5.0 rev. 120706.zip"
$targetFolder = "E:\inetpub\wwwroot"

# Additional variables
$packageFileName = [System.IO.Path]::GetFileNameWithoutExtension($sourcePath)
$dataFolder = "$targetFolder\$packageFileName\Data"
$websiteFolder = "$targetFolder\$packageFileName\Website"
$serverName = $env:COMPUTERNAME
$sqlServerName = "$serverName\SQLEXPRESS"

# Main Script
Unzip-Archive $sourcePath $targetFolder

$server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $sqlServerName
$databases = "core", "master", "web"
foreach ($db in $databases)
{
    Attach-Database $server "$siteName.$db" "$targetFolder\$packageFileName\Databases\Sitecore.$db.mdf" "$targetFolder\$packageFileName\Databases\Sitecore.$db.ldf"
	Set-ConnectionString "$websiteFolder\App_Config\ConnectionStrings.config" "$db" "Trusted_Connection=Yes;Data Source=$sqlServerName;Database=$siteName.$db"
}

Set-ConfigAttribute "$websiteFolder\web.config" "sitecore/sc.variable[@name='dataFolder']" "value" $dataFolder   

Copy-Item $licensePath $dataFolder
Create-AppPool $siteName "v4.0"
Create-Site $siteName "$siteName.local"  "$destination\$packageFileName"
Add-HostFileContent "127.0.0.1" "$siteName.local"
