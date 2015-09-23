<#
.SYNOPSIS 
    Runs Azure AD Graph API REST calls
    
.DESCRIPTION
    This function runs AD Graph API REST calls against Azure Active Direcotry. 

.PARAMETER Username
    Name of a user that has access to Azure Active Direcotry.
    It should be of the format "user@contoso.onmicrosoft.com". Don't set this value if using application authentication

.PARAMETER Password
    Password that matches the Username. Set this if an AD user is used for authentication.
    
.PARAMETER AzureADDomain
    The Azure Active Directory domain
    It should be of the format contoso.onmicrosoft.com 

.PARAMETER APIVersion
    The version of the REST API to work against. Default is 2013-03-01

.PARAMETER AppIdURI
    The application URI you want to perform actions against. This will be included in the JWT token
    that is returned. Default is https://management.core.windows.net/

.PARAMETER ClientID
    The Azure Active Directory client identifier for a registered application. 
    The default for this is the well known PowerShell application client ID 1950a258-227b-4e31-a9cf-717495945fc2 that
    will be used if a specific one is not passed in.

.PARAMETER Secret
    The secret associated with the Client ID application.
   
.PARAMETER Connection
    A hashtable that contains the Username, Password, and AzureADDomain, ClientID, Secret, AppIDURI, APIVersion
    
.PARAMETER URI
    A REST URI to run

.PARAMETER Method
    The REST method to use
    Values can be "GET", "POST", "PUT", "DELETE", "PATCH"

.PARAMETER Body
    The body for the REST call
    This parameter is only required if the method is a POST, PATCH, or PUT

.EXAMPLE
    # Get the list of users in Azure Active Direcotry
    $URI = "https://graph.windows.net/contoso.onmicrosoft.com/users/"

    Invoke-AzureADMethod -URI $URI -Method "GET" -Username "user@contoso.onmicrosoft.com" -Password "StrongPassword" -AzureADDomain "contoso.onmicrosoft.com"
 
.EXAMPLE
    # Create a new user
    $URI = "https://graph.windows.net/contoso.onmicrosoft.com/users/"

    # New AD user to create
    $NewADUser = "TestUser"
    $Password = "StrongPassword"
    $AzureADDomain = "contoso.onmicrosoft.com"

    # Create body content for the REST call with the new user
$Body = @"
{
    "accountEnabled": true,
    "displayName": "$NewADUser",
    "mailNickname": "$NewADUser",
    "passwordProfile": { "password" : "$Password", "forceChangePasswordNextLogin": false },
    "userPrincipalName": "$NewADUser@$AzureADDomain"
}
"@

    # Set up connection value to make it easier to pass in information to get access to Azure AD
    $ADConnection = @{"Username"="user@contoso.onmicrosoft.com";"AzureADDomain"="contoso.onmicrosoft.com";"Password"="StrongPassword"}
    
    Invoke-AzureADMethod -URI $URI -Method "POST" -Body $Body -Connection $ADConnection

.EXAMPLE
    # Authenticate to Azure AD using client application registered in Azure AD and perform actions against the Azure Resource Manager
    $ClientID = "Client ID of the application"
    $Secret = "Secret Key of the application"
    $AzureADDomain = "contoso.onmicrosoft.com"
    $APIVersion = "2015-01-01"
    $APPIdURI = "https://management.core.windows.net/"

    # Set up connection value to make it easier to pass in information to get access to Azure AD
    $ADConnection = @{"AzureADDomain"=$AzureADDomain;"Secret"=$Secret;"APPIdURI"=$APPIdURI;"ClientID"=$ClientID;"APIVersion"=$APIVersion}
    
    # Get a list of resources in ARM
    $URI = "https://management.azure.com/subscriptions/$SubscriptionId/resources"
   
    Invoke-AzureADMethod -URI $URI -Method "GET" -Connection $ADConnection
       
.NOTES
    AUTHOR: Eamon O'Reilly
    LASTEDIT: May 14th, 2015 
#>
Function Invoke-AzureADMethod
{
    Param(
        [Parameter(ParameterSetName='ADCredential', Position=0, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Username = $null,

        [Parameter(ParameterSetName='ADCredential', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Password,

        [Parameter(ParameterSetName='ADCredential', Position=2, Mandatory=$True)]
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=2, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AzureADDomain,

        # Operate against the Azure API by default. Could go against Azure AD with https://graph.windows.net 
        [Parameter(ParameterSetName='ADCredential', Position=2, Mandatory=$False)]
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=2, Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AppIdURI = "https://management.core.windows.net/",

        # Well know PowerShell Client ID is the default if an specific client is not specified
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=0, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClientID = "1950a258-227b-4e31-a9cf-717495945fc2",

        # Well know PowerShell Client ID is the default if an specific client is not specified
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=0, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret,

        [Parameter(Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [string]
        $APIVersion = "2013-03-01",

        [Parameter(ParameterSetName='UseConnectionObject', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Connection,

        [Parameter(Mandatory=$True)]
        [String]
        $URI,

        [Parameter(Mandatory=$True)]
        [ValidateSet('GET','POST','DELETE','PUT','PATCH')]
        [String]
        $Method,

        [Parameter(Mandatory=$False)]
        [String]
        $Body
        )

        # Use connection if specific values were set
        if ($Connection -ne $null) 
        { 
            if ($Connection.UserName -ne $null) { $Username = $Connection.UserName }
            if ($Connection.Password -ne $null) { $Password = $Connection.Password }
            $AzureADDomain = $Connection.AzureADDomain
            if ($Connection.AppIdURI -ne $null) { $AppIdURI = $Connection.AppIdURI }
            if ($Connection.ClientId -ne $null) { $ClientId = $Connection.ClientId }
            if ($Connection.Secret -ne $null) { $Secret = $Connection.Secret }
            if ($Connection.APIVersion -ne $null) { $APIVersion = $Connection.APIVersion }
        }


        # Get a JSON web token

        # Use the UserName & Password to authenticate
        if ($Username -ne $null -and $Username -ne "")
        {
            Write-Verbose ("Using Username and password for authentication." + "Username is : " + $Username)
            $AuthHeader = Get-AzureADToken -Username $Username -Password $Password -AzureADDomain $AzureADDomain -AppIdURI $AppIdURI
        }
        # Else, we are authenticating against an applicaiton using the secret key for this applicaiton client id.
        else
        {
            Write-Verbose ("Using application with secret key for authentication." + "Application ID is : " + $ClientID)
            $AuthHeader = Get-AzureADToken -ClientID $ClientID -AzureADDomain $AzureADDomain -AppIdURI $AppIdURI -Secret $Secret
        }
    

        $Header = @{
        "x-ms-version" = "$APIVersion";
        "Authorization" = $AuthHeader
        }

        # Add the API version
        $URI = $URI + "?api-version=$APIVersion"

        If ($Method -eq "GET")
        {
            Invoke-RestMethod -Uri $URI -Method $Method -Headers $Header
        }
        Else
        {
            Invoke-RestMethod -Uri $URI -Method $Method -Headers $Header -Body $Body -ContentType "application/json"
        }
}

<#
.SYNOPSIS 
    Gets an Azure AD authentication token that can be used it future calls 
    
.DESCRIPTION
    This cmdlet returns an Azure AD token that can be used when making calls against resources integrated with Azure Active Directory. 

.PARAMETER Username
    Name of a user that has access to Azure Active Direcotry.
    It should be of the format "user@contoso.onmicrosoft.com". Don't set this value if using application authentication

.PARAMETER Password
    Password that matches the Username. Set this if an AD user is used for authentication.
    
.PARAMETER AzureADDomain
    The Azure Active Directory domain
    It should be of the format contoso.onmicrosoft.com 

.PARAMETER AppIdURI
    The application URI you want to perform actions against. This will be included in the JWT token
    that is returned. Default is https://management.core.windows.net/. If you want to make calls against Azure AD directly,
    then you can set this to https://graph.windows.net/

.PARAMETER ClientID
    The Azure Active Directory client identifier for a registered application. 
    The default for this is the well known PowerShell application client ID 1950a258-227b-4e31-a9cf-717495945fc2 that
    will be used if a specific one is not passed in.

.PARAMETER Secret
    The secret associated with the Client ID application.
   
.PARAMETER Connection
    A hashtable that contains the Username, Password, and AzureADDomain, ClientID, Secret, AppIDURI
    

.EXAMPLE
    # Get a token to run commands against the Azure AD Graph API.
    $URI = "https://graph.windows.net/contoso.onmicrosoft.com/users/"

    $Token = Get-AzureADToken -Username "user@contoso.onmicrosoft.com" -Password "StrongPassword" -AzureADDomain "contoso.onmicrosoft.com" -AppIdURI "https://graph.windows.net"
    
    $URI = "https://graph.windows.net/contoso.onmicrosoft.com/users?api-version=beta" 

    $Header = @{
        "x-ms-version" = "beta";
        "Authorization" = $Token
    }

    Invoke-RestMethod -URI $URI -Headers $Header -Method GET
 

       
.NOTES
    AUTHOR: Eamon O'Reilly
    LASTEDIT: April 15th, 2015 
#>
Function Get-AzureADToken
{
    Param(
        [Parameter(ParameterSetName='ADCredential', Position=0, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Username = $null,

        [Parameter(ParameterSetName='ADCredential', Position=1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Password,

        [Parameter(ParameterSetName='ADCredential', Position=2, Mandatory=$True)]
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=2, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AzureADDomain,

        # Operate against the Azure API by default. Could go against Azure AD with https://graph.windows.net 
        [Parameter(ParameterSetName='ADCredential', Position=2, Mandatory=$False)]
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=2, Mandatory=$False)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AppIdURI = "https://management.core.windows.net/",

        # Well know PowerShell Client ID is the default if an specific client is not specified
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=0, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $ClientID = "1950a258-227b-4e31-a9cf-717495945fc2",

        # Well know PowerShell Client ID is the default if an specific client is not specified
        [Parameter(ParameterSetName='ClientApplicationCredential', Position=0, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Secret,

        [Parameter(ParameterSetName='UseConnectionObject', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Connection
        )

        # Use connection if specific values were set
        if ($Connection -ne $null) 
        { 
            if ($Connection.UserName -ne $null) { $Username = $Connection.UserName }
            if ($Connection.Password -ne $null) { $Password = $Connection.Password }
            $AzureADDomain = $Connection.AzureADDomain
            if ($Connection.AppIdURI -ne $null) { $AppIdURI = $Connection.AppIdURI }
            if ($Connection.ClientId -ne $null) { $ClientId = $Connection.ClientId }
            if ($Connection.Secret -ne $null) { $Secret = $Connection.Secret }
        }


        # Get a JSON web token

        # Use the UserName & Password to authenticate
        if ($Username -ne $null -and $Username -ne "")
        {
            Write-Verbose "Using Azure AD Credentials"
            # Set up authority to the common authentication
            $Authority = "https://login.windows.net/common"
            $AuthContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $Authority, $False
            $Creds = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserCredential" -ArgumentList $UserName, $Password
            $ClientID = "1950a258-227b-4e31-a9cf-717495945fc2"
            $AuthResult = $AuthContext.AcquireToken($AppIdURI, $ClientId, $Creds)
        }
        # Else, we are authenticating against an applicaiton using the secret key for this applicaiton client id.
        else
        {
            Write-Verbose "Using Azure AD Application with secret key"
            # Set up authority to the domain the application is part of.
            $Authority = "https://login.windows.net/$AzureADDomain"

            $AuthContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $Authority, $False
            $Creds = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential" -ArgumentList $ClientID, $Secret
            $AuthResult = $AuthContext.AcquireToken($AppIdURI, $Creds)
        }

       
        # Return token
        $AuthResult.CreateAuthorizationHeader()

}
