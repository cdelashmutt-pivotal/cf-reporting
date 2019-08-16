$result = cf curl '/v2/events' | ConvertFrom-Json
$data = $result.resources

while( $results.next_url -ne $null ) {
  Write-Host Getting $results.next_url
  $results = cf curl $results.next_url | ConvertFrom-Json
  $data += $results.resources
}

$results | select-object 
  @{Name="metadata_guid"; Expression={$_.metadata.guid}}
  ,@{Name="metadata_url"; Expression={$_.metadata.url}}
  ,@{Name="metadata_created_at"; Expression={$_.metadata.created_at}}
  ,@{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}}
  ,@{Name="entity_type"; Expression={$_.entity.type}}
  ,@{Name="entity_actor"; Expression={$_.entity.actor}}
  ,@{Name="entity_actor_type"; Expression={$_.entity.actor_type}}
  ,@{Name="entity_actor_name"; Expression={$_.entity.actor_name}}
  ,@{Name="entity_actor_username"; Expression={$_.entity.actor_username}}
  ,@{Name="entity_actee"; Expression={$_.entity.actee}}
  ,@{Name="entity_actee_type"; Expression={$_.entity.actee_type}}
  ,@{Name="entity_actee_name"; Expression={$_.entity.actee_name}}
  ,@{Name="entity_timestamp";Expression={$_.entity.timestamp}}
  ,@{Name="entity_metadata_build_guid";Expression={$_.entity.metadata.build_guid}}
  ,@{Name="entity_metadata_package_guid";Expression={$_.entity.metadata.package_guid}}
  ,@{Name="entity_space_guid";Expression={$_.entity.space_guid}}
  ,@{Name="entity_organization_guid";Expression={$_.entity.organization_guid}} 
| Export-Csv -NoTypeInformation events.csv

