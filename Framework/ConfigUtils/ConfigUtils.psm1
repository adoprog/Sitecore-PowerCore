<#
	.DESCRIPTION
		Setup forms.config 
#>
function Setup-FormsConfig([string]$webroot, [xml]$config)
{	
	Write-Output "Setup forms.config"
	
	$formsConfigTemplatePath = "$webroot\website\App_Config\Include\forms.config.template"
	$formsConfigPath = $formsConfigTemplatePath.Substring(0, $formsConfigTemplatePath.LastIndexOf('.'))
	
	#get content of forms.config.template
	$formsConfig = [xml](get-content $formsConfigTemplatePath)	
		
	$connectionString = $formsConfig.configuration.sitecore.SelectSingleNode("formsDataProvider/param[@desc='connection string']")
	$connectionString.InnerText = $config.InstallSettings.ConnectionStrings.Forms.Replace("(Source)" , $config.InstallSettings.DatabaseDeployment.DatabaseServer)
			
	# save xml content to connectionStrings.config
	$formsConfig.Save($formsConfigPath)
}

<#
	.DESCRIPTION
		Uncomment analytics scheduling
#>
function Uncomment-AnalyticsSchedule([string]$webroot)
{	
	Write-Output "uncommentAnalyticsSchedule - started"
	
	$analyticsConfigPath = "$webroot\website\App_Config\Include\Sitecore.Analytics.config"
    Uncomment-ConfigSection $analyticsConfigPath "Sitecore.Analytics.Tasks.SubscriptionTask, Sitecore.Analytics"
    Uncomment-ConfigSection $analyticsConfigPath "Sitecore.Analytics.Tasks.EmailReportsTask"
    Uncomment-ConfigSection $analyticsConfigPath "Sitecore.Analytics.Tasks.UpdateReportsSummaryTask"    
}

<#
	.DESCRIPTION
		Uncomment ECM scheduling
#>
function Uncomment-ECMSchedule([string]$webroot)
{	
	Write-Output "uncommentECMSchedule - started"
	
	$ecmConfigPath = "$webroot\website\App_Config\Include\Sitecore.EmailCampaign.config"
    Uncomment-ConfigSection $ecmConfigPath "<scheduling>"  
}

<#
	.DESCRIPTION
		Disable Analytics Lookups
#>
function Disable-AnalyticsLookups([string]$webroot)
{	
	$analyticsConfigPath = "$webroot\website\App_Config\Include\Sitecore.Analytics.config"    
    Set-SitecoreSetting $analyticsConfigPath "Analytics.PerformLookup" "false"    
	
	Write-Output "Analytics lookups disabled."
}

<#
	.DESCRIPTION
		Enable Shell Redirect
        For example - redirect from /sitecore to cms.sitecore.net
#>
function Enable-ShellRedirect([string]$webroot)
{	
	$redirectConfigPath = "$webroot\website\sitecore\web.config.disabled"
	$redirectConfigEnabledPath = "$webroot\website\sitecore\web.config"

    if (Test-Path $redirectConfigPath)
    {
        $redirectConfig = Get-Item $redirectConfigPath  -ErrorAction SilentlyContinue
        Rename-Item $redirectConfigPath $redirectConfigEnabledPath -Verbose
    }
    
	Write-Output "Shell redirect enabled"
}

<#
	.DESCRIPTION
		Disable Analytics for all sites in <sites> section of Web.config
#>
function Disable-SitesAnalytics([string]$webroot)
{	
    Write-Output "Disabling analytics for <sites>" 
	$webConfigPath = "$webroot\website\Web.config"
    $webConfig = [xml](get-content $webConfigPath)

    foreach ($i in $webConfig.SelectNodes("/configuration/sitecore/sites"))
    {
        foreach ($site in $i.ChildNodes) 
        {
            $site.SetAttribute("enableAnalytics", "false")                    
        }
    }  
   
    $webConfig.Save($webConfigPath)
}

<#
	.DESCRIPTION
		Set AutomationMachineName setting in config
#>
function Set-AutomationMachineName([string]$webroot, [string]$machineName)
{	
	Write-Output "Setting Automation.MachineName to $machineName"
	$analyticsConfigPath = "$webroot\website\App_Config\Include\Sitecore.Analytics.config"    
    Set-SitecoreSetting $analyticsConfigPath "Analytics.Automation.MachineName" $machineName
}

<#
	.DESCRIPTION
		Set Execution Timeout
#>
function Set-ExecutionTimeout([string]$webroot, [string] $timeout)
{
	Write-Output "Setting Execution Timeout in web.config to $timeout"
	
    $webConfigPath = "$webroot\website\web.config"	
    Set-ConfigAttribute $webConfigPath "system.web/httpRuntime" "executionTimeout" $timeout
}

# Enable LocalMTA
<#
	.DESCRIPTION
		
#>
function EnableLocalMTA([string]$webroot)
{
	Write-Output "Enabling local MTA"
	
	$websiteConfigPath = "$webroot\website\App_Config\Include\Sitecore.EmailCampaign.config"
    Set-SitecoreSetting $websiteConfigPath "UseLocalMTA" "true"    
    Set-SitecoreSetting $websiteConfigPath "SMTP.AuthMethod" "NONE"         
}

<#
	.DESCRIPTION
		Disable Chars Validation
#>
function Disable-CharsValidation([string]$webroot)
{
	Write-Output "Disabling Chars Validation"
	
	$webConfigPath = "$webroot\website\web.config"    
    Set-SitecoreSetting $webConfigPath "InvalidItemNameChars" ""
	Set-SitecoreSetting $webConfigPath "ItemNameValidation" "^[\w\*\$][\.\w\s\-\$]*(\(\d{1,}\)){0,1}$" 	
}

<#
	.DESCRIPTION
		Enable Chars Validation
#>
function Enable-CharsValidation([string]$webroot)
{
	Write-Output "Enabling Chars Validation"
	
	$webConfigPath = "$webroot\website\web.config"
	$InvalidItemNameChars = $config.InstallSettings.CustomSettings.InvalidItemNameChars
    Set-SitecoreSetting $webConfigPath "InvalidItemNameChars" $InvalidItemNameChars
	Set-SitecoreSetting $webConfigPath "ItemNameValidation" "^[\w\*\$][\w\s\-\$]*(\(\d{1,}\)){0,1}$" 	
}

<#
	.DESCRIPTION
		Set Config Attribute
#>
function Set-ConfigAttribute([string]$configPath, [string] $xpath, [string] $attribute, [string] $value)
{
    Write-Output "Setting attribute $xpath in $configPath to $value"
	
	$config = [xml](get-content $configPath)
	$config.configuration.SelectSingleNode($xpath).SetAttribute($attribute, $value)	
	$config.Save($configPath)
}

<#
	.DESCRIPTION
		Set Connection String
#>
function Set-ConnectionString([string]$configPath, [string] $connectionStringName, [string] $value)
{
    Write-Output "Setting connection string $connectionStringName in $configPath to $value"
	
	$config = [xml](get-content $configPath)
	$config.SelectSingleNode("connectionStrings/add[@name='$connectionStringName']").SetAttribute("connectionString", $value)	
	$config.Save($configPath)
}

<#
	.DESCRIPTION
		Set Sitecore Setting
#>
function Set-SitecoreSetting([string]$configPath, [string] $name, [string] $value)
{
    Write-Output "Setting Sitecore setting $name"
	
    $xpath = "settings/setting[@name='" + $name + "']"   
	$config = [xml](get-content $configPath)
	$config.configuration.sitecore.SelectSingleNode($xpath).SetAttribute("value", $value)	
	$config.Save($configPath)
}

<#
	.DESCRIPTION
		Uncomment config file section
#>
function Uncomment-ConfigSection([string]$configPath, [string] $pattern)
{
    Write-Output "Uncommenting section containing text $pattern in $configPath"

    $xDoc = [System.Xml.Linq.XDocument]::Load($configPath)
    $endpoints = $xDoc.Descendants("configuration") | foreach { $_.DescendantNodes()}               
    
    $configSection = $endpoints | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Comment -and $_.Value -match $pattern }        
    if ($configSection -ne $NULL)
    {    
        $configSection | foreach { $_.ReplaceWith([System.Xml.Linq.XElement]::Parse($_.Value)) }
    }
    
    $emailReportsAgent | foreach { Write-Output $_.Value; }
    $xDoc.Save($configPath)
}

<#
	.DESCRIPTION
		Enable Elmah tool
#>
function Enable-Elmah([string]$webRoot)
{    
    Write-Output "Enableing Elmah"
    
    $webConfig = "$webroot\website\web.config"

    Uncomment-ConfigSection $webConfig "Elmah.ErrorLogModule, Elmah"
    Uncomment-ConfigSection $webConfig "Elmah.ErrorFilterModule, Elmah"
    Uncomment-ConfigSection $webConfig "Elmah.ErrorMailModule, Elmah"
    
    $xpath = "elmah/errorMail"
    $attribute = "subject"
    
    $config = [xml](get-content $webConfig)
	$attrValue = $config.configuration.SelectSingleNode($xpath).GetAttribute($attribute);
    Set-ConfigAttribute $webConfig $xpath $attribute $attrValue.Replace("#SERVERNAME#", [Environment]::MachineName);
}

<#
	.DESCRIPTION
		Turn On Crm Profiling
#>
function Enable-CrmProfiling([string]$webroot)
{
    Write-Output "Enabling CRM Profiling"
    
    $webConfig = "$webroot\website\web.config"
    $crmConfig = "$webroot\website\App_Config\Include\crm.config"
    
    $attributeName = "providerName"
    $targetProvider = "wrapper"
    
    $webConfigContents = [xml](get-content $webConfig)
    
    # Change crm providers for wrappers 
    $xpath = "sitecore/switchingProviders/membership/provider[@providerName='crm']";
    $attrValue = $webConfigContents.configuration.SelectSingleNode($xpath);
    if($attrValue -ne $NULL)
    {
        Set-ConfigAttribute $webConfig $xpath $attributeName $targetProvider;
    }
    
    $xpath = "sitecore/switchingProviders/roleManager/provider[@providerName='crm']";
    $attrValue = $webConfigContents.configuration.SelectSingleNode($xpath);
    if($attrValue -ne $NULL)
    {
        Set-ConfigAttribute $webConfig $xpath $attributeName $targetProvider;        
    }
    
    $xpath = "sitecore/switchingProviders/profile/provider[@providerName='crm']";
    $attrValue = $webConfigContents.configuration.SelectSingleNode($xpath);
    if($attrValue -ne $NULL)
    {
        Set-ConfigAttribute $webConfig $xpath $attributeName $targetProvider;        
    }            
    
    # Turn on crm profiling setting
    Set-SitecoreSetting $crmConfig "Crm.CrmAccessProfiling" "true";
        
    Write-Output "Enable-CrmProfiling - done"
}

Export-ModuleMember -function Setup-FormsConfig
Export-ModuleMember -function Uncomment-AnalyticsSchedule
Export-ModuleMember -function Uncomment-ECMSchedule
Export-ModuleMember -function Disable-AnalyticsLookups
Export-ModuleMember -function Enable-ShellRedirect
Export-ModuleMember -function Disable-SitesAnalytics
Export-ModuleMember -function Set-AutomationMachineName
Export-ModuleMember -function Set-ExecutionTimeout
Export-ModuleMember -function EnableLocalMTA
Export-ModuleMember -function Disable-CharsValidation
Export-ModuleMember -function Enable-CharsValidation
Export-ModuleMember -function Set-ConfigAttribute
Export-ModuleMember -function Set-ConnectionString
Export-ModuleMember -function Set-SitecoreSetting
Export-ModuleMember -function Uncomment-ConfigSection
Export-ModuleMember -function Enable-Elmah
Export-ModuleMember -function Enable-CrmProfiling