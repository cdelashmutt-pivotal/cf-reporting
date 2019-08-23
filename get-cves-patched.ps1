param (
    [string] $Target,
    [string] $UserName,
    [securestring] $Password,
    [datetime] $StartDate = (Get-Date | Get-Date -Day 1),
    [datetime] $EndDate = (get-date | foreach { $_.AddMonths(1) | Get-Date -Day 1 })
)

$updates = om curl --path /api/v0/installations | ConvertFrom-JSON | select -ExpandProperty installations | where { $_.finished_at -gt $StartDate.ToString("yyyy-MM-dd") -and $_.finished_at -lt $EndDate.ToString("yyyy-MM-dd") } | select -ExpandProperty updates | select identifier, product_version -Unique
$updates | foreach {
    $version=($_.product_version).Split("-")[0]
    pivnet release /p $_.identifier /r $version /format json | ConvertFrom-Json
}