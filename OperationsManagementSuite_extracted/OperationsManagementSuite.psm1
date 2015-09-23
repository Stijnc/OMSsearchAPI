<#
.SYNOPSIS 
    Gets the Operations Management Suite workspace or all workspace if one is not specified
    
.DESCRIPTION
    This cmdlet retrives all of the Operations Mangement Suite workspaces or a specific
    one if specified

.PARAMETER Token
    The Azure AD token that has access to the OMS workspace. Use the AzureActiveDirectory module on 
    ScriptCenter to retrieve the token by calling the Get-AzureADToken cmdlet

.PARAMETER SubscriptionID
    Subscription ID that the OMS workspace is in

.PARAMETER Region
    The name of the region that the OMS workspace is in. Examples are East-US, West-Europe
    
.PARAMETER Workspace
    The name of the workspace to retrieve information about. Optional Parameter

.PARAMETER APIVersion
    The API version to use for OMS Queries. Default is 2014-10-10. Optional Parameter
    
.PARAMETER Connection
    A hashtable that contains the SubscriptionID, Region, Workspace, and APIVersion

.EXAMPLE
    # Get list of all workspaces in a subscription for a particular region

    # Get the authentication token from Azure AD. Can use the AzureActiveDirectory Module example on
    # ScriptCenter or a different call to get the token. 
    $Token = Get-AzureADToken -Connection $ADConnection

    Get-OMSWorkspace -Token $Token -SubscriptionID "bccac418-bb95-422e-8e83-ddb7060aa359" -Region "East-US"
 
.EXAMPLE
    # Get a specific workspace in a subscription for a particular region
    
    # Get the authentication token from Azure AD. Can use the AzureActiveDirectory Module example on
    # ScriptCenter or a different call to get the token. 
    $Token = Get-AzureADToken -Connection $ADConnection

    # Set up the connection object for OMS
    $OMSConnection = @{"WorkSpace"="contoso";"SubscriptionID"="bccac418-bb95-422e-8e83-ddb7060aa359";"Region"="East-US";"APIVersion"="2014-10-10"}

    Get-OMSWorkspace -Token $Token -Connection $OMSConnection
        
.NOTES
    AUTHOR: Eamon O'Reilly
    LASTEDIT: May 16th, 2015 
#>
Function Get-OMSWorkspace {
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Token,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $SubscriptionID,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [String] $Workspace,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Region,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [String] $APIVersion = "2014-10-10",

        [Parameter(ParameterSetName='UseConnectionObject', Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Connection

    )

    # Use connection if specific values were set
    if ($Connection -ne $null) 
    { 
        if ($Connection.SubscriptionID -ne $null) { $SubscriptionID = $Connection.SubscriptionID }
        if ($Connection.Workspace -ne $null) { $WorkSpace = $Connection.Workspace }
        if ($Connection.Region -ne $null) { $Region = $Connection.Region }
        if ($Connection.APIVersion -ne $null) { $APIVersion = $Connection.APIVersion }
    }

    $Url = "https://management.azure.com/subscriptions/$SubscriptionID/resourcegroups/OI-Default-$Region/providers/Microsoft.OperationalInsights"
    
    # Add workspace if one is specified, otherwise return all workspaces
    if ($WorkSpace -ne "") { $Url = "${Url}/workspaces/" + "$Workspace"}
    else { $Url = "${Url}/workspaces"}

    # Add version to URL
    $Url = $Url + "?api-version=$APIVersion"
    Write-Verbose ("OMS URL is: " + $Url)

    $Header = @{"Authorization"="${Token}"}

    $Result = Invoke-RestMethod -Method Get -Headers $Header -Uri $Url

    # Return array values to make them more PowerShell friendly
    if ($Result.value -ne $null) {$Result.value}
    else {$Result}
}

<#
.SYNOPSIS 
    Searches the Operations Management Suite workspace with a specific query
    
.DESCRIPTION
    This cmdlet searches all of the Operations Mangement Suite workspace with a specific query

.PARAMETER Token
    The Azure AD token that has access to the OMS workspace. Use the AzureActiveDirectory module on 
    ScriptCenter to retrieve the token by calling the Get-AzureADToken cmdlet

.PARAMETER SubscriptionID
    Subscription ID that the OMS workspace is in

.PARAMETER Region
    The name of the region that the OMS workspace is in. Examples are East-US, West-Europe
    
.PARAMETER Workspace
    The name of the workspace to retrieve information about. Optional Parameter

.PARAMETER APIVersion
    The API version to use for OMS Queries. Default is 2014-10-10. Optional Parameter

.PARAMETER Query
    The Query to run against OMS. You can copy the query from the OMS search box
    
.PARAMETER Connection
    A hashtable that contains the SubscriptionID, Region, Workspace, and APIVersion

.EXAMPLE
    # Get list of all error alerts that are not closed

    # Get the authentication token from Azure AD. Can use the AzureActiveDirectory Module example on
    # ScriptCenter or a different call to get the token. 
    $Token = Get-AzureADToken -Connection $ADConnection

    $Query = 'Type:Alert AlertSeverity:Error AlertState!=Closed'

    # Set up the connection object for OMS
    $OMSConnection = @{"WorkSpace"="contoso";"SubscriptionID"="bccac418-bb95-422e-8e83-ddb7060aa359";"Region"="East-US";"APIVersion"="2014-10-10"}

    Search-OMSWorkspace -Token $Token -Query $Query -Connection $OMSConnection
        
.NOTES
    AUTHOR: Eamon O'Reilly
    LASTEDIT: May 16th, 2015 
#>
Function Search-OMSWorkspace {
    Param(
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Token,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $SubscriptionID,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Workspace,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Query,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String] $Region,

        [Parameter(ParameterSetName='OMSInformation', Position=1, Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [String] $APIVersion = "2014-10-10",

        [Parameter(ParameterSetName='UseConnectionObject', Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Connection
    )

    # Use connection if specific values were set
    if ($Connection -ne $null) 
    { 
        if ($Connection.SubscriptionID -ne $null) { $SubscriptionID = $Connection.SubscriptionID }
        if ($Connection.WorkSpace -ne $null) { $Workspace = $Connection.Workspace }
        if ($Connection.Region -ne $null) { $Region = $Connection.Region }
        if ($Connection.APIVersion -ne $null) { $APIVersion = $Connection.APIVersion }
    }

    $Url = "https://management.azure.com/subscriptions/$SubscriptionID/resourcegroups/OI-Default-$Region/providers/Microsoft.OperationalInsights/"
    $QueryUrl = "${Url}workspaces/" + $Workspace + "/search?api-version=$APIVersion"
    Write-Verbose ("OMS URL is: " + $WorkspaceUrl)

    $Header = @{"Authorization"="${Token}"}

    $QueryBody = "{'Query':'$Query'}"
    Write-Verbose ("OMS Query is: " + $QueryBody)

    $Result = Invoke-RestMethod -Method Post -Headers $Header -Uri $QueryUrl -Body $QueryBody -ContentType "application/json"
    
    # Return array values to make them more PowerShell friendly
    if ($Result.value -ne $null) {$Result.value}
    else {$Result}
}
