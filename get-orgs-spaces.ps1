Write-Host Getting orgs
$result = cf curl '/v2/organizations' | ConvertFrom-Json
$data = $result.resources

while( $result.next_url -ne $null ) {
  Write-Host Getting next orgs page from $result.next_url
  $result = cf curl $result.next_url | ConvertFrom-Json
  $data += $result.resources
}

Write-Host Writing orgs to csv
$data | select-object @{Name="metadata_guid"; Expression={$_.metadata.guid}},
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
  Export-Csv -NoTypeInformation organizations.csv

Write-Host Getting spaces
$result = cf curl '/v2/spaces' | ConvertFrom-Json
$data = $result.resources

while( $result.next_url -ne $null ) {
  Write-Host Getting next space page from $result.next_url
  $result = cf curl $result.next_url | ConvertFrom-Json
  $data += $result.resources
}

Write-Host Writing spaces to csv
$data | select-object @{Name="metadata_guid"; Expression={$_.metadata.guid}},
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
  Export-Csv -NoTypeInformation spaces.csv



