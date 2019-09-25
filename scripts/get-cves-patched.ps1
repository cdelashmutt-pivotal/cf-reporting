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

# Get the change log, with the individual additions and updates flattened
$changeLog = (om -t $Target -u $creds.UserName -p "$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds.Password)))" $(if ($SkipSSLValidation) {"--skip-ssl-validation"}) curl --path /api/v0/installations -s | 
    ConvertFrom-Json | 
    select -ExpandProperty installations | 
    foreach { 
        $installation = $_
        $installation.updates + $installation.additions | select-object @{Name="id"; Expression={$installation.id}},
            @{Name="user_name"; Expression={$installation.user_name}},
            @{Name="finished_at"; Expression={$installation.finished_at}},
            @{Name="started_at"; Expression={$installation.started_at}},
            @{Name="status"; Expression={$installation.status}},
            @{Name="identifier"; Expression={$_.identifier}},
            @{Name="label"; Expression={$_.label}},
            @{Name="product_version"; Expression={$_.product_version}},
            @{Name="deployment_status"; Expression={$_.deployment_status}},
            @{Name="change_type"; Expression={$_.change_type}},
            @{Name="guid"; Expression={$_.guid}}
        }
)

# Collect the latest updates in the timeframe requested
$updates = (
    $changeLog | 
    where { 
        $_.deployment_status -eq "successful" -and
        $_.change_type -eq "update" -and
        $_.finished_at -gt $StartDate.ToString("yyyy-MM-dd") -and
        $_.finished_at -lt $EndDate.ToString("yyyy-MM-dd")
    } | 
    group-object identifier | 
    foreach {
        $_.Group | Sort-Object -Descending finished_at | Select -First 1
    }
)

$updateRanges = $updates | 
    foreach {
        $update = $_
        $lineage = (
            $changeLog | 
            where { 
                $_.identifier -eq $update.identifier -and $_.deployment_status -eq "successful" 
            }
        )
        $returnValue = $null
        foreach($item in ($lineage | select -skip 1)) { 
            $returnValue = $item
            if ($item.finished_at -lt $StartDate.ToString("yyyy-MM-dd")) { break }
        }
        # If the previous version was the same, we had no updates this month 
        if ($update.product_version -eq $returnValue.product_version) { $returnValue = $null}
        [PSCustomObject] @{"Start"=$returnValue;"End"=$update}
    } | where { $_.Start -ne $null }

# Force TLS 1.2 for subsequent requests
[System.Net.ServicePointManager]::SecurityProtocol = "Tls12"

# Regex to match strings that look like CVE codes
[regex]$cveRegex = 'CVE-\d{4}-\d{1,}'

# Regex to match cflinuxfs3 version number
[regex]$cflinuxfs3VersionRegex = 'cflinuxfs3<\/td>.*<td>([^<]*)<\/td>'

pivnet login --api-token $PivNetToken

Class CVEEntry {
    [string]$Component
    [string]$CVE

    [bool]Equals([object]$x)
    { 
        return $x.GetType() -eq [CVEEntry] -and $x.Component -eq $This.Component -and $x.CVE -eq $This.CVE 
    }
    [int]GetHashCode() 
    { 
        return [tuple]::Create($This.Component,$This.CVE).GetHashCode() 
    }
  }
$cves = New-Object System.Collections.Generic.HashSet[PSCustomObject]

$updateRanges | foreach {
    # These get reversed because we're looking for the end version first on the page
    $StartRange = $_.End
    $EndRange = $_.Start
    $version=($StartRange.product_version).Split("-")[0]
    $endVersion=($EndRange.product_version).Split("-")[0]
    write-host Product: $EndRange.identifier Version: $StartRange.product_version to $EndRange.product_version
    Write-Host '-' Attempting to find release notes page for $EndRange.identifier
    $product_data = (pivnet release -p $EndRange.identifier -r $version --format json | ConvertFrom-Json)
    if($product_data.release_notes_url -ne $null) {
        # Regex-s for finding the start and end of the block of text on the release notes page for the version we're scanning
        [regex]$versionStartRegex = '<h3 id="[^"]*">[^<]*<a[^>]*>[^<]*<\/a>[^<]*'+$product_data.version
        [regex]$versionEndRegex = '<h3 id="[^"]*">[^<]*<a[^>]*>[^<]*<\/a>[^<]*'+$endVersion
        [regex]$finalSectionRegex = '<h3'

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
                $cve = [CVEEntry]@{Component=$EndRange.identifier;CVE=$match.Value}
                [void]$cves.Add($cve)
            }

            # For CF, we want to collect up all the CVEs in cflinuxfs3
            if( $StartRange.identifier -eq "cf" ) {
                # Grab the additional release note text, if needed, so we can get the starting cflinuxfs version
                if($endIdx+1 -gt $release_note_data.Length) {
                    $release_version_section_with_final = $release_version_section
                } else {
                    $endMatches = $finalSectionRegex.Matches($release_note_data.Substring($endIdx+1))
                    $release_version_section_with_final = $release_note_data.Substring($startIdx, (($endIdx + $endMatches[0].Groups[0].Index)-$startIdx))
                }
                # Find the version number of cflinuxfs3 included with this product version
                $matches = $cflinuxfs3VersionRegex.Matches($release_version_section_with_final)
                $firstVersion = $matches[0].Groups[1]
                $lastVersion = $matches[$matches.Count-1].Groups[1]
                $cfLinuxTags = invoke-restmethod "https://api.github.com/repos/cloudfoundry/cflinuxfs3/tags"
                # Get all the tags between the latest and last version, but skip the last version
                $firstVersionIdx = $null
                $lastVersionIdx = $null
                for($idx=0; $idx -lt $cfLinuxTags.Length; $idx++) {
                    if($cfLinuxTags[$idx].name -eq $firstVersion) { $firstVersionIdx = $idx }
                    if($cfLinuxTags[$idx].name -eq $lastVersion) { break }
                    $lastVersionIdx = $idx
                }
                foreach ($tag in $cfLinuxTags[$firstVersionIdx..$lastVersionIdx]) {
                    Write-Host "Looking for CVEs fixed in cflinuxfs3 version $($tag.name):"
                    # Cross reference the cflinuxfs3 version with the github release for that project
                    $cflinuxfs3Info = (invoke-restmethod "https://api.github.com/repos/cloudfoundry/cflinuxfs3/releases/tags/$($tag.name)")
                    # Extract the CVEs patched in that rootfs
                    foreach ($match in $cveRegex.Matches($cflinuxfs3Info.body) ) {
                        $cve = [CVEEntry]@{Component="cflinuxfs3";CVE=$match.Value}
                        [void]$cves.Add($cve)
                    }
                }
            }
        }
    }
}

$cves