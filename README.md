Sitecore PowerShell Deployment Framework
==================

Helper modules which can be used to create simple Sitecore website deployment script in something like 50 lines of code.

**DBUtils.psm1**

Basic DB operations - backup / restore / execute, etc.

* Create-Database
* Restore-Database
* Backup-Database
* Attach-Database
* Execute-File

**FileUtils.psm1**

Used to download / extract / package files, etc.

* Download-File
* Extract-Package
* Set-Permissions
* Unzip-Archive
* Add-HostFileContent

**ConfigUtils.psm1**

All about editing .config files - web.config, include files, ConnectionStrings.config

* Uncomment-ConfigSection
* Set-ConnectionString
* Set-SitecoreSetting
* Set-ConfigAttribute
* Set-ExecutionTimeout

and many other cmdlets

**IISUtils.psm1**

Used to create Sites / AppPools in IIS

* Create-AppPool
* Create-Site

**SvnUtils.psm1**

Contains single commandlet which will Checkout / Revert / Update folder from specified SVN repository. It can be split into a few different ones, I plan to do it in future.

**WebUtils.psm1**

Includes single commandlet for invoking a web page

**Deployment script example**

 ```powershell
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
$dataFolder = "$destination\$packageFileName\Data"
$websiteFolder = "$destination\$packageFileName\Website"
$serverName = $env:COMPUTERNAME
$sqlServerName = "$serverName\SQLEXPRESS"

# Main Script
Unzip-Archive $sourcePath $targetFolder

$server = New-Object ("Microsoft.SqlServer.Management.Smo.Server") $sqlServerName
$databases = "core", "master", "web"
foreach ($db in $databases)
{
  Attach-Database $server "$siteName.$db" "$targetFolder\$packageFileName\Databases\Sitecore.$db.mdf" "$destination\$packageFileName\Databases\Sitecore.$db.ldf"
  Set-ConnectionString "$websiteFolder\App_Config\ConnectionStrings.config" "$db" "Trusted_Connection=Yes;Data Source=$sqlServerName;Database=$siteName.$db"
}

Set-ConfigAttribute "$websiteFolder\web.config" "sitecore/sc.variable[@name='dataFolder']" "value" $dataFolder   

Copy-Item $licensePath $dataFolder
Create-AppPool $siteName "v4.0"
Create-Site $siteName "$siteName.local"  "$destination\$packageFileName"
Add-HostFileContent "127.0.0.1" "$siteName.local"

 ```
