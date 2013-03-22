<#
	.DESCRIPTION
		Connects specified folder to SVN. This includes checkout / revert / update
#>
function Connect-FolderToSVN([string]$svnUrl, [string]$svnLocalPath, [string]$svnUsername, [string]$svnPassword)
{
    if ([System.IO.Path]::IsPathRooted($svnLocalPath) -eq $false)  
    {  
      throw "Please specify a local absolute path"  
    }  

    # Creates a SharpSVN SvnClient object  
    $svnClient = new-object SharpSvn.SvnClient  

    # Set the username / password
    $credentials = new-object System.Net.NetworkCredential($svnUsername, $svnPassword)   
    $svnClient.Authentication.DefaultCredentials = $credentials; 
            
    # Creates a SharpSVN SvnUriTarget object  
    $repoUri = new-object SharpSvn.SvnUriTarget($svnUrl)  
      
    # Perform the checkout (i.e. downloads files from SVN to specified local directory) 
    Write-Output "Checking out $repoUri to $svnLocalPath" 
    $cargs = new-object SharpSvn.SvnCheckOutArgs
    $cargs.Depth = 3
    $cargs.AllowObstructions = $true;
    $result = $NULL
    $svnClient.CheckOut($repoUri, $svnLocalPath,  $cargs, [ref] $result)  

    Write-Output "Reverting $svnLocalPath"
    $args = new-object SharpSvn.SvnRevertArgs
    $args.Depth = 3 #SvnDepth.Infinity == 3   
    $svnClient.Revert($svnLocalPath, $args)  
    
    Write-Output "Updating $svnLocalPath" 
    $svnClient.Update($svnLocalPath)
}

Export-ModuleMember -function Connect-FolderToSVN