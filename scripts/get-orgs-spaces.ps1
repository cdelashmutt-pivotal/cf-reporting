<#
.SYNOPSIS
    Exports all the orgs and spaces from the Cloud Foundry Cloud Controller

.DESCRIPTION
    This script logs in to the Cloud Foundry API endpoint you specify and 
    downloads all the orgs and spaces into a CSV file.

.EXAMPLE
    .\Get-Orgs-Spaces.ps1 -PlatformName FOG -Api api.sys.fog.onefiserv.net -UserName cdelashmutt

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

  Write-Host Getting orgs
  $result = cf curl '/v2/organizations' | ConvertFrom-Json
  $data = $result.resources

  while( $result.next_url -ne $null ) {
    Write-Host Getting next orgs page from $result.next_url
    $result = cf curl $result.next_url | ConvertFrom-Json
    $data += $result.resources
  }

  Write-Host Writing orgs to csv
  $data | select-object @{Name="platform"; Expression={$PlatformName}},
    @{Name="metadata_guid"; Expression={$_.metadata.guid}},
    @{Name="metadata_url"; Expression={$_.metadata.url}},
    @{Name="metadata_created_at"; Expression={$_.metadata.created_at}},
    @{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}},
    @{Name="entity_name"; Expression={$_.entity.name}},
    @{Name="entity_billing_enabled"; Expression={$_.entity.billing_enabled}},
    @{Name="entity_quota_definition_guid"; Expression={$_.entity.quota_definition_guid}},
    @{Name="entity_status"; Expression={$_.entity.status}},
    @{Name="entity_default_isolation_segment_guid"; Expression={$_.entity.default_isolation_segment_guid}},
    @{Name="entity_quota_definition_url"; Expression={$_.entity.quota_definition_url}},
    @{Name="entity_spaces_url"; Expression={$_.entity.spaces_url}},
    @{Name="entity_domains_url"; Expression={$_.entity.domains_url}},
    @{Name="entity_private_domains_url";Expression={$_.entity.private_domains_url}},
    @{Name="entity_users_url";Expression={$_.entity.users_url}},
    @{Name="entity_managers_url";Expression={$_.entity.managers_url}},
    @{Name="entity_billing_managers_url";Expression={$_.entity.billing_managers_url}},
    @{Name="entity_auditors_url";Expression={$_.entity.auditors_url}},
    @{Name="entity_app_events_url";Expression={$_.entity.app_events_url}},
    @{Name="entity_space_quota_definitions_url";Expression={$_.entity.space_quota_definitions_url}} | 
    Export-Csv -NoTypeInformation organizations.csv -Append:$Append

  Write-Host Getting spaces
  $result = cf curl '/v2/spaces' | ConvertFrom-Json
  $data = $result.resources

  while( $result.next_url -ne $null ) {
    Write-Host Getting next space page from $result.next_url
    $result = cf curl $result.next_url | ConvertFrom-Json
    $data += $result.resources
  }

  Write-Host Writing spaces to csv
  $data | select-object @{Name="platform"; Expression={$PlatformName}},
    @{Name="metadata_guid"; Expression={$_.metadata.guid}},
    @{Name="metadata_url"; Expression={$_.metadata.url}},
    @{Name="metadata_created_at"; Expression={$_.metadata.created_at}},
    @{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}},
    @{Name="entity_name"; Expression={$_.entity.name}},
    @{Name="entity_organization_guid"; Expression={$_.entity.organization_guid}},
    @{Name="entity_space_quota_definition_guid"; Expression={$_.entity.space_quota_definition_guid}},
    @{Name="entity_isolation_segment_guid"; Expression={$_.entity.isolation_segment_guid}},
    @{Name="entity_allow_ssh"; Expression={$_.entity.allow_ssh}},
    @{Name="entity_organization_url"; Expression={$_.entity.organization_url}},
    @{Name="entity_developers_url"; Expression={$_.entity.developers_url}},
    @{Name="entity_managers_url"; Expression={$_.entity.managers_url}},
    @{Name="entity_auditors_url";Expression={$_.entity.auditors_url}},
    @{Name="entity_apps_url";Expression={$_.entity.apps_url}},
    @{Name="entity_routes_url";Expression={$_.entity.routes_url}},
    @{Name="entity_domains_url";Expression={$_.entity.domains_url}},
    @{Name="entity_service_instances_url";Expression={$_.entity.service_instances_url}},
    @{Name="entity_app_events_url";Expression={$_.entity.app_events_url}},
    @{Name="entity_events_url";Expression={$_.entity.events_url}},
    @{Name="entity_security_groups_url";Expression={$_.entity.security_groups_url}},
    @{Name="entity_staging_security_groups_url";Expression={$_.entity.staging_security_groups_url}} | 
    Export-Csv -NoTypeInformation spaces.csv -Append:$Append
}
