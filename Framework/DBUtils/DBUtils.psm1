[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null

<#
	.DESCRIPTION
		Creates new database on specified SQL server. Existing DB will be overwritten
#>
Function New-Database ($server, $databaseName, $DatabasePath)
{
    if($DatabasePath) {
        $dataFileFolder = $DatabasePath
        $logFileFolder = $DatabasePath

    }
    else {
	    $dataFileFolder = $server.Settings.DefaultFile
	    $logFileFolder = $server.Settings.DefaultLog
    }

	if ($dataFileFolder -eq $NULL -or $dataFileFolder.Length -eq 0) {
	    $dataFileFolder = $server.Information.MasterDBPath
	}
	if ($logFileFolder -eq $NULL -or $logFileFolder.Length -eq 0) {
	    $logFileFolder = $server.Information.MasterDBLogPath
	}
    
    Write-Host "Data files folder - " $dataFileFolder
    Write-Host "Log files folder"    $logFileFolder
    Write-Host " " 
    
    "Removing existing database - " + $databaseName
    IF ($server.databases[$databaseName] -ne $NULL) {
        $server.databases[$databaseName].drop()
    }
    
    # Instantiate the database object and add the filegroups
    $db = new-object ('Microsoft.SqlServer.Management.Smo.Database') ($server, $databaseName)
    $sysfg = new-object ('Microsoft.SqlServer.Management.Smo.FileGroup') ($db, 'PRIMARY')
    $db.FileGroups.Add($sysfg)

    # Create the file for the system tables
    $syslogname = $databaseName
    $dbdsysfile = new-object ('Microsoft.SqlServer.Management.Smo.DataFile') ($sysfg, $syslogname)
    $sysfg.Files.Add($dbdsysfile)
    $dbdsysfile.FileName = $dataFileFolder + '\' + $syslogname + '.mdf'
    $dbdsysfile.Size = [double](5.0 * 1024.0)
    $dbdsysfile.GrowthType = 'KB'
    $dbdsysfile.Growth = 25000
    $dbdsysfile.IsPrimaryFile = 'True'

    # Create the file for the log
    $loglogname = $databaseName + '_log'
    $dblfile = new-object ('Microsoft.SqlServer.Management.Smo.LogFile') ($db, $loglogname)
    $db.LogFiles.Add($dblfile)
    $dblfile.FileName = $logFileFolder + '\' + $loglogname + '.ldf'
    $dblfile.Size = [double](10.0 * 1024.0)
    $dblfile.GrowthType = 'KB'
    $dblfile.Growth = 25000

    # Create the database
    $db.Collation = 'SQL_Latin1_General_CP1_CI_AS'
    $db.CompatibilityLevel = 'Version100'
    $db.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Simple
    
    "Creating new database - " + $databaseName
    $db.Create()

    $db.SetOwner('sa')
}

<#
	.DESCRIPTION
		Deletes the database on the specified SQL server. 
#>
Function Remove-Database ($server, $databaseName)
{
    "Removing the database - " + $databaseName
    IF ($server.databases[$databaseName] -ne $NULL) {
        $server.KillAllProcesses($databaseName)
        $server.KillDatabase($databaseName)
    }
}

<#
	.DESCRIPTION
		Restores database from provided backup file
#>
Function Restore-Database ($server, $database, $backupFile)
{
	$backupDevice = New-Object("Microsoft.SqlServer.Management.Smo.BackupDeviceItem") ($backupFile, "File")

	# Load up the Restore object settings
	$Restore = new-object ("Microsoft.SqlServer.Management.Smo.Restore")
	$Restore.Action = 'Database' 
	$Restore.Database = $database
    $Restore.ReplaceDatabase = $true
	$Restore.Norecovery = $false
    $Restore.Devices.Add($backupDevice)

    $db = $server.databases[$database]
    
    Write-Host $db.FileGroups["PRIMARY"].Files[0].FileName
    Write-Host $db.LogFiles[0].FileName
    
    # Get information from the backup file
	$RestoreDetails = $Restore.ReadBackupHeader($server)
	$DataFiles = $Restore.ReadFileList($server)

	# Restore all backup files
	ForEach ($DataRow in $DataFiles) {
        $LogicalName = $DataRow.LogicalName
		$RestoreData = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile")
		$RestoreData.LogicalFileName = $LogicalName
		if ($DataRow.Type -eq "D") {
			# Restore Data file
			$RestoreData.PhysicalFileName = $db.FileGroups["PRIMARY"].Files[0].FileName 
		}
		Else {
			# Restore Log file
			$RestoreData.PhysicalFileName = $db.LogFiles[0].FileName
		}
		[Void]$Restore.RelocateFiles.Add($RestoreData)
	}
	$Restore.SqlRestore($server)

    "Backup restored: " + $server + $backupFile 
}

<#
	.DESCRIPTION
		Backups database with the specified name.
#>
Function Backup-Database ($database, $server, $backupFile)
{
    Write-Host "Backup database" + $database.Name + "started"
    Write-Host "Backup file:" $backupFile
    $dbBackup = new-Object ("Microsoft.SqlServer.Management.Smo.Backup")
    $dbRestore = new-object ("Microsoft.SqlServer.Management.Smo.Restore")

    $dbBackup.Database = $database.Name
    $dbBackup.Devices.AddDevice($backupFile, "File")

    $dbBackup.Action="Database"
    $dbBackup.Initialize = $TRUE
    $dbBackup.PercentCompleteNotification = 10
    $dbBackup.SqlBackup($server)  
    
    Write-Host "Backup database" + $database.Name + "finished"
}

<#
	.DESCRIPTION
		Attaches database on specified SQL server. Existing DB will be detached
#>
Function Set-Database ($server, $databaseName, $dataFileName, $logFileName)
{
    if ($server.databases[$databaseName] -ne $NULL) {
        $server.DetachDatabase($databaseName, $false)
    }

	$sc = new-object System.Collections.Specialized.StringCollection; 
	$sc.Add($dataFileName) | Out-Null; 
	$sc.Add($logFileName) | Out-Null;
	
	$server.AttachDatabase($databaseName, $sc); 
    Write-Output "Database $databaseName successfully attached."
}

<#
	.DESCRIPTION
		Executes SQL file at the specified server / database
#>
Function Invoke-File ($server, $database, $file) 
{
    Write-Output "Executin Sql file $file at $server/$database"
    Invoke-SqlCmd -inputfile $file -serverinstance $server -database $database
}

New-Alias -Name Create-Database  -Value New-Database
New-Alias -Name Delete-Database  -Value Remove-Database
New-Alias -Name Execute-File  -Value Invoke-File
New-Alias -Name Attach-Database  -Value Set-Database
  
Export-ModuleMember -function New-Database
Export-ModuleMember -function Restore-Database
Export-ModuleMember -function Remove-Database
Export-ModuleMember -function Backup-Database
Export-ModuleMember -function Set-Database
Export-ModuleMember -function Invoke-File

Export-ModuleMember -Alias *
