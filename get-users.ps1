Write-Host Getting users
$result = cf curl '/v2/users' | ConvertFrom-Json
$data = $result.resources

while( $result.next_url -ne $null ) {
  Write-Host Getting next users page from $result.next_url
  $result = cf curl $result.next_url | ConvertFrom-Json
  $data += $result.resources
}

Write-Host Writing users to csv
$data | select-object @{Name="metadata_guid"; Expression={$_.metadata.guid}},
  @{Name="metadata_url"; Expression={$_.metadata.url}},
  @{Name="metadata_created_at"; Expression={$_.metadata.created_at}},
  @{Name="metadata_updated_at"; Expression={$_.metadata.updated_at}},
  @{Name="entity_admin"; Expression={$_.entity.admin}},
  @{Name="entity_active"; Expression={$_.entity.active}},
  @{Name="entity_default_space_guid"; Expression={$_.entity.default_space_guid}},
  @{Name="entity_username"; Expression={$_.entity.username}} | 
  Export-Csv -NoTypeInformation users.csv


