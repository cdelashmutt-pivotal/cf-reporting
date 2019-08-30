<#
.SYNOPSIS
    Exports all the events from the Cloud Foundry Cloud Controller

.DESCRIPTION
    This script logs in to the Cloud Foundry API endpoint you specify and 
    downloads all the available events into a CSV file.

.EXAMPLE
    .\Get-Events.ps1 -PlatformName FOG -Api api.sys.fog.onefiserv.net -UserName cdelashmutt

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

    Write-Host Getting events
    $result = cf curl '/v2/events' | ConvertFrom-Json
    $data = $result.resources

    while( $result.next_url -ne $null ) {
        Write-Host Getting next events page from $result.next_url
        $result = cf curl $result.next_url | ConvertFrom-Json
        $data += $result.resources
    }

    Write-Host Writing events to csv
    $data | select-object @{Name="platform"; Expression={$PlatformName}},
        @{Name="metadata_guid"; Expression={$_.metadata.guid}}
        @{Name="metadata_url"; Expression={$_.metadata.url}},
        @{Name="metadata_created_at"; Expression={$_.metadata.created_at}},
        @{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}},
        @{Name="entity_type"; Expression={$_.entity.type}},
        @{Name="entity_actor"; Expression={$_.entity.actor}},
        @{Name="entity_actor_type"; Expression={$_.entity.actor_type}},
        @{Name="entity_actor_name"; Expression={$_.entity.actor_name}},
        @{Name="entity_actor_username"; Expression={$_.entity.actor_username}},
        @{Name="entity_actee"; Expression={$_.entity.actee}},
        @{Name="entity_actee_type"; Expression={$_.entity.actee_type}},
        @{Name="entity_actee_name"; Expression={$_.entity.actee_name}},
        @{Name="entity_timestamp";Expression={$_.entity.timestamp}},
        @{Name="entity_metadata_build_guid";Expression={$_.entity.metadata.build_guid}},
        @{Name="entity_metadata_package_guid";Expression={$_.entity.metadata.package_guid}},
        @{Name="entity_space_guid";Expression={$_.entity.space_guid}},
        @{Name="entity_organization_guid";Expression={$_.entity.organization_guid}} |
    Export-Csv -NoTypeInformation events.csv -Append:$Append
}
