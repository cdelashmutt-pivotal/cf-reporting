param (
    # OpsManager Hostname
    [Parameter(Mandatory = $true)]
    [string] $Target,
    # Username for OpsManager
    [Parameter(Mandatory = $true)]
    [string] $UserName,
    # PivNet Refresh Token from your user profile page
    [Parameter(Mandatory = $true)]
    [string] $PivNetToken,
#    [Parameter(Mandatory = $true)]
#    [securestring] $Password,
    # The name of the platform to add to reporting data
    [Parameter(Mandatory = $true)]
    [string] $Platform,
    # Allows skipping SSL Validation if needed
    [switch]$SkipSSLValidation=$false,
    # Start date for the report
    [datetime] $StartDate = (Get-Date | Get-Date -Day 1),
    # End date for the report
    [datetime] $EndDate = (get-date | foreach { $_.AddMonths(1) | Get-Date -Day 1 })
)

$creds = Get-Credential -UserName $UserName -Message "Enter your FEAD Shortname and Password"
if(!$creds){ 
    Write-Error You must provide valid credentials for the Ops Manager API at $Api for the Platform $PlatformName
    exit -1
}
 
$updates = (
    om -t $Target -u $creds.UserName -p "$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds.Password)))" $(if ($SkipSSLValidation) {"--skip-ssl-validation"}) curl --path /api/v0/installations -s | 
    ConvertFrom-JSON | 
    select -ExpandProperty installations | 
    where { 
        $_.finished_at -gt $StartDate.ToString("yyyy-MM-dd") -and 
        $_.finished_at -lt $EndDate.ToString("yyyy-MM-dd") -and
        $_.status -eq "succeeded"
    } | 
    select -ExpandProperty updates | 
    select identifier, product_version -Unique
)

# Force TLS 1.2 for subsequent requests
[System.Net.ServicePointManager]::SecurityProtocol = "Tls12"

pivnet login /api-token $PivNetToken
$updates | foreach {
    $version=($_.product_version).Split("-")[0]
    write-host Product: $_.identifier Version: $_.product_version
    Write-Host '-' Attempting to find release notes page for $_.identifier
    $product_data = (pivnet release /p $_.identifier /r $version /format json | ConvertFrom-Json)
    if($product_data.release_notes_url -ne $null) {
        $ProgressPreference = 'SilentlyContinue'
        Write-Host '-' Looking up CVE Data from $product_data.release_notes_url
        [regex]$cveRegex = 'CVE-\d{4}-\d{1,}'
        [regex]$versionStartRegex = '<h2 id="[^"]*">[^<]*<a[^>]*>[^<]*</a>[^<]*'+$product_data.version
        [regex]$versionEndRegex = '<h2 id="[^"]*">[^<]*<a[^>]*>[^<]*</a>[^<]*'
        $data = (invoke-webrequest "$($product_data.release_notes_url)" | select -ExpandProperty content)
        Write-Host '-' Attempting to find data for version $product_data.version on release notes page
        $startMatches = $versionStartRegex.Matches($data)
        $startIdx = -1
        if($startMatches.Length -gt 0 ) { $startIdx = $startMatches[0].Index}
        if($startIdx -ne -1) {
            Write-Host '-' Looking for CVE mentions
            $endMatches = $versionEndRegex.Matches($data)
            $endIdx = -1
            foreach ($match in $endMatches) {
                if($match.Index -gt $startIdx) { 
                    $endIdx = $match.Index
                    break 
                }
            }
            if( $endIdx -eq -1) { $endIdx = $data.Length}
            foreach ($match in $cveRegex.Matches($data.Substring($startIdx,($endIdx-$startIdx))) ) {
                Write-Host '--' $match.Value
            }
        }
    }

    # Need to get stemcell and cflinuxf3 patches
}