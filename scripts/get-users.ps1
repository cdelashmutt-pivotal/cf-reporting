<#
.SYNOPSIS
    Exports all the users from the Cloud Foundry Cloud Controller

.DESCRIPTION
    This script logs in to the Cloud Foundry API endpoint you specify and 
    downloads all the users into a CSV file.

.EXAMPLE
    .\Get-Users.ps1 -PlatformName FOG -Api api.sys.fog.onefiserv.net -UserName cdelashmutt

.LINK
    https://apidocs.cloudfoundry.org/11.1.0/

.NOTES
    This script expects that the CF CLI has been installed you can get the latest CLI version from 
    https://github.com/cloudfoundry/cli#installers-and-compressed-binaries
#>
param(
    # The friendly name of the platform you are extracting data from.
    # This string is added to each row of data extracted for reporting purposes.
    [Parameter(Mandatory = $true)]
    [string]$PlatformName,

    # The hostname for the API endpoint of the platform to extract events from. 
    [Parameter(Mandatory = $true)]
    [string]$Api,

    # The username to use to login to the API endpoint
    [Parameter(Mandatory = $true)]
    [string]$UserName,

    # Allows skipping SSL Validation if needed
    [switch]$SkipSSLValidation=$false,

    # Append to existing export file
    [switch]$Append=$false

)

$creds = Get-Credential -UserName $UserName -Message "Enter your FEAD Shortname and Password"
if(!$creds){ 
    Write-Error You must provide valid credentials for the Cloud Controller API at $Api for the Platform $PlatformName
    exit -1
}

$skipSSLArg = if ($SkipSSLValidation) {"--skip-ssl-validation"}

# Target and authenticate
& cf api $Api $skipSSLArg
& cf.exe auth $creds.UserName "$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds.Password)))"

if($?)
{

  Write-Host Getting users
  $result = cf curl '/v2/users' | ConvertFrom-Json
  $data = $result.resources

  while( $result.next_url -ne $null ) {
    Write-Host Getting next users page from $result.next_url
    $result = cf curl $result.next_url | ConvertFrom-Json
    $data += $result.resources
  }

  Write-Host Writing users to csv
  $data | select-object @{Name="platform"; Expression={$PlatformName}},
    @{Name="metadata_guid"; Expression={$_.metadata.guid}},
    @{Name="metadata_url"; Expression={$_.metadata.url}},
    @{Name="metadata_created_at"; Expression={$_.metadata.created_at}},
    @{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}},
    @{Name="entity_admin"; Expression={$_.entity.admin}},
    @{Name="entity_active"; Expression={$_.entity.active}},
    @{Name="entity_default_space_guid"; Expression={$_.entity.default_space_guid}},
    @{Name="entity_username"; Expression={$_.entity.username}} | 
    Export-Csv -NoTypeInformation users.csv -Append:$Append
}