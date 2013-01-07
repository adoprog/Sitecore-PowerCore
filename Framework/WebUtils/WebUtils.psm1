function Get-WebPage {
	param($url)
	
	if (!$url.StartsWith("http://"))
	{
		$url = "http://" + $url
	}
	
	Write-Output "Creating request to $url"
	$request = [system.net.WebRequest]::Create($url)
	$request.Timeout = 2400000
	return $request.GetResponse()		
}

Export-ModuleMember -function Get-WebPage