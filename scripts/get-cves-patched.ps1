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

# Regex to match strings that look like CVE codes
[regex]$cveRegex = 'CVE-\d{4}-\d{1,}'

# Regex to match cflinuxfs3 version number
[regex]$cflinuxfs3VersionRegex = 'cflinuxfs3<\/td>.*<td>([^<]*)<\/td>'

pivnet login --api-token $PivNetToken
$updates | foreach {
    $version=($_.product_version).Split("-")[0]
    write-host Product: $_.identifier Version: $_.product_version
    Write-Host '-' Attempting to find release notes page for $_.identifier
    $product_data = (pivnet release -p $_.identifier -r $version --format json | ConvertFrom-Json)
    if($product_data.release_notes_url -ne $null) {
        # Regex-s for finding the start and end of the block of text on the release notes page for the version we're scanning
        [regex]$versionStartRegex = '<h3 id="[^"]*">[^<]*<a[^>]*>[^<]*<\/a>[^<]*'+$product_data.version
        [regex]$versionEndRegex = '<h3 id="[^"]*">[^<]*<a[^>]*>[^<]*<\/a>[^<]*'

        $ProgressPreference = 'SilentlyContinue'
        Write-Host '-' Looking up CVE Data from $product_data.release_notes_url

        # Get the entire release notes HTML page for a product
        $release_note_data = (invoke-webrequest "$($product_data.release_notes_url)" | select -ExpandProperty content)

        Write-Host '-' Attempting to find data for version $product_data.version on release notes page
        $startMatches = $versionStartRegex.Matches($release_note_data)
        $startIdx = -1
        if($startMatches.Length -gt 0 ) { $startIdx = $startMatches[0].Index}
        if($startIdx -ne -1) {
            Write-Host '-' Looking for CVE mentions
            # Find the block of text cooresponding to the version we're scanning for
            $endMatches = $versionEndRegex.Matches($release_note_data)
            $endIdx = -1
            foreach ($match in $endMatches) {
                if($match.Index -gt $startIdx) { 
                    $endIdx = $match.Index
                    break 
                }
            }
            if( $endIdx -eq -1) { $endIdx = $release_note_data.Length }

            $release_version_section = $release_note_data.Substring($startIdx,($endIdx-$startIdx))

            # Grab anything that looks like a CVE string
            foreach ($match in $cveRegex.Matches($release_version_section) ) {
                Write-Host '--' $match.Value
            }

            # For CF, we want to collect up all the CVEs in cflinuxfs3
            if( $_.identifier -eq "cf" ) {
                # Find the version number of cflinuxfs3 included with this product version
                foreach($match in $cflinuxfs3VersionRegex.Matches($release_version_section)) {
                    $cflinuxfs3Version = $match.Groups[1]
                    Write-Host "Looking for CVEs fixed in cflinuxfs3 version $($cflinuxfs3Version):"
                    # Cross reference the cflinuxfs3 version with the github release for that project
                    $cflinuxfs3Info = (invoke-restmethod "https://api.github.com/repos/cloudfoundry/cflinuxfs3/releases/tags/$cflinuxfs3Version")
                    # Extract the CVEs patched in that rootfs
                    foreach ($match in $cveRegex.Matches($cflinuxfs3Info.body) ) {
                        Write-Host '--' $match.Value
                    }
                }
            }
        }
    }
}