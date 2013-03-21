
function Export-SourceModulesToSession
{
    Param(
     [Management.Automation.Runspaces.PSSession]
     [ValidateNotNull()]
     $Session,
 
    [IO.FileInfo[]]
    [ValidateNotNull()]
    [ValidateScript(
    {
      (Test-Path $_) -and (!$_.PSIsContainer) -and ($_.Extension -eq '.psm1')
    })]
   $ModulePaths
  )
 
   $remoteModuleImportScript = {
     Param($Modules)
 
     Write-Host "Writing $($Modules.Count) modules to temporary disk location"
 
     $Modules |
       % {
         $path = ([IO.Path]::GetTempFileName()  + '.psm1')
         $_.Contents | Out-File -FilePath $path -Force
         "Importing module [$($_.Name)] from [$path]"
         Import-Module $path
       }
   }
 
  $modules = $ModulePaths | % { @{Name = $_.Name; Contents = Get-Content $_ } }
  $params = @{
    Session = $Session;
    ScriptBlock = $remoteModuleImportScript;
    Argumentlist = @(,$modules);
  }
 
  Invoke-Command @params
}

Export-ModuleMember -function Export-SourceModulesToSession