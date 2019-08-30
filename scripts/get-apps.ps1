<#
.SYNOPSIS
    Exports all the apps from the Cloud Foundry Cloud Controller

.DESCRIPTION
    This script logs in to the Cloud Foundry API endpoint you specify and 
    downloads all the apps into a CSV file.

.EXAMPLE
    .\Get-Apps.ps1 -PlatformName FOG -Api api.sys.fog.onefiserv.net -UserName cdelashmutt

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
  Write-Host Getting apps
  $result = cf curl '/v2/apps'
  # Add anything that produces a duplicate key error to this list until Powershell 6.0 is available 
  $result = $result -creplace '"BuildPack":', '"BuildPack_":' -creplace '"BillerLogoCachingTimeinHrs":', '"BillerLogoCachingTimeinHrs_":' -creplace '"http_proxy":', '"http_proxy_":' -creplace '"https_proxy":', '"https_proxy_":'
  $result = $result | ConvertFrom-Json
  $data = $result.resources

  while( $result.next_url -ne $null ) {
    Write-Host Getting next apps page from $result.next_url
    $result = cf curl $result.next_url
    $result = $result -creplace '"BuildPack":', '"BuildPack_":' -creplace '"BillerLogoCachingTimeinHrs":', '"BillerLogoCachingTimeinHrs_":' -creplace '"http_proxy":', '"http_proxy_":' -creplace '"https_proxy":', '"https_proxy_":'
    $result = $result | ConvertFrom-Json
    $data += $result.resources
  }

  Write-Host Writing apps to csv
  $data | select-object  @{Name="platform"; Expression={$PlatformName}},
    @{Name="metadata_guid"; Expression={$_.metadata.guid}},
    @{Name="metadata_url"; Expression={$_.metadata.url}},
    @{Name="metadata_created_at"; Expression={$_.metadata.created_at}},
    @{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}},
    @{Name="entity_name"; Expression={$_.entity.name}},
    @{Name="entity_production"; Expression={$_.entity.production}},
    @{Name="entity_space_guid"; Expression={$_.entity.space_guid}},
    @{Name="entity_stack_guid"; Expression={$_.entity.stack_guid}},
    @{Name="entity_buildpack"; Expression={$_.entity.buildpack}},
    @{Name="entity_detected_buildpack"; Expression={$_.entity.detected_buildpack}},
    @{Name="entity_memory"; Expression={$_.entity.memory}},
    @{Name="entity_instances"; Expression={$_.entity.instances}},
    @{Name="entity_state"; Expression={$_.entity.state}},
    @{Name="entity_version"; Expression={$_.entity.version}},
    @{Name="entity_command"; Expression={$_.entity.command}},
    @{Name="entity_console"; Expression={$_.entity.console}},
    @{Name="entity_debug"; Expression={$_.entity.debug}},
    @{Name="entity_staging_task_id"; Expression={$_.entity.staging_task_id}},
    @{Name="entity_package_state"; Expression={$_.entity.package_state}},
    @{Name="entity_health_check_type"; Expression={$_.entity.health_check_type}},
    @{Name="entity_health_check_timeout"; Expression={$_.entity.health_check_timeout}},
    @{Name="entity_health_check_http_endpoint"; Expression={$_.entity.health_check_http_endpoint}},
    @{Name="entity_staging_failed_reason"; Expression={$_.entity.staging_failed_reason}},
    @{Name="entity_staging_failed_description"; Expression={$_.entity.staging_failed_description}},
    @{Name="entity_diego"; Expression={$_.entity.diego}},
    @{Name="entity_docker_image"; Expression={$_.entity.docker_image}},
    @{Name="entity_package_updated_at"; Expression={$_.entity.package_updated_at}},
    @{Name="entity_detected_start_command"; Expression={$_.entity.detected_start_command}},
    @{Name="entity_enable_ssh"; Expression={$_.entity.enable_ssh}},
    @{Name="entity_space_url"; Expression={$_.entity.space_url}},
    @{Name="entity_stack_url"; Expression={$_.entity.stack_url}},
    @{Name="entity_routes_url"; Expression={$_.entity.routes_url}},
    @{Name="entity_events_url"; Expression={$_.entity.events_url}},
    @{Name="entity_service_bindings_url"; Expression={$_.entity.service_bindings_url}},
    @{Name="entity_route_mappings_url"; Expression={$_.entity.route_mappings_url}} | 
    Export-Csv -NoTypeInformation apps.csv -Append:$Append
}