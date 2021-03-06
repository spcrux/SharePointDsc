function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]  [System.String] $Name,
        [parameter(Mandatory = $true)]  [System.Boolean] $Enabled,
        [parameter(Mandatory = $false)] [ValidateSet("All Servers","Any Server")] [System.String] $RuleScope,
        [parameter(Mandatory = $false)] [ValidateSet("Hourly","Daily","Weekly","Monthly","OnDemandOnly")] [System.String] $Schedule,
        [parameter(Mandatory = $false)] [System.Boolean] $FixAutomatically,
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $InstallAccount
    )

    Write-Verbose -Message "Getting Health Rule configuration settings"

    $result = Invoke-SPDSCCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
        $params = $args[0]
        
        try {
            $spFarm = Get-SPFarm
        } catch {
            Write-Verbose -Verbose "No local SharePoint farm was detected. Health Analyzer Rule settings will not be applied"
            return $null
        }

        $caWebapp = Get-SPwebapplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
        if ($null -eq $caWebapp) {
            Write-Verbose -Verbose "Unable to locate central administration website"
            return $null
        }

        # Get CA SPWeb
        $caWeb = Get-SPWeb($caWebapp.Url)
        $healthRulesList = $caWeb.Lists | ? { $_.BaseTemplate -eq "HealthRules"}

        if ($healthRulesList -ne $null) {
            $spQuery = New-Object Microsoft.SharePoint.SPQuery 
            $querytext =   "<Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($params.Name)</Value></Eq></Where>"
            $spQuery.Query = $querytext
            $results = $healthRulesList.GetItems($spQuery)
            if ($results.Count -eq 1) {
                $item = $results[0]

                return @{
                    # Set the Health Analyzer Rule settings
                    Name = $params.Name
                    Enabled = $item["HealthRuleCheckEnabled"]
                    RuleScope = $item["HealthRuleScope"]
                    Schedule = $item["HealthRuleSchedule"]
                    FixAutomatically = $item["HealthRuleAutoRepairEnabled"]
                    InstallAccount = $params.InstallAccount
                }
            } else {
                Write-Verbose -Verbose "Unable to find specified Health Analyzer Rule"
                return $null                
            }
        } else {
            Write-Verbose -Verbose "Unable to locate Health Analyzer Rules list"
            return $null
        }       
    }

    return $result
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]  [System.String] $Name,
        [parameter(Mandatory = $true)]  [System.Boolean] $Enabled,
        [parameter(Mandatory = $false)] [ValidateSet("All Servers","Any Server")] [System.String] $RuleScope,
        [parameter(Mandatory = $false)] [ValidateSet("Hourly","Daily","Weekly","Monthly","OnDemandOnly")] [System.String] $Schedule,
        [parameter(Mandatory = $false)] [System.Boolean] $FixAutomatically,
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $InstallAccount
    )

    Write-Verbose -Message "Setting Health Analyzer Rule configuration settings"

    Invoke-SPDSCCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
        $params = $args[0]

        try {
            $spFarm = Get-SPFarm
        } catch {
            throw "No local SharePoint farm was detected. Health Analyzer Rule settings will not be applied"
            return
        }

        $caWebapp = Get-SPwebapplication -includecentraladministration | where {$_.IsAdministrationWebApplication}
        if ($null -eq $caWebapp) {
            throw "No Central Admin web application was found. Health Analyzer Rule  settings will not be applied"
            return
        }

        # Get Central Admin SPWeb
        $caWeb = Get-SPWeb($caWebapp.Url)
        $healthRulesList = $caWeb.Lists | ? { $_.BaseTemplate -eq "HealthRules"}

        if ($healthRulesList -ne $null) {
            $spQuery = New-Object Microsoft.SharePoint.SPQuery 
            $querytext =   "<Where><Eq><FieldRef Name='Title'/><Value Type='Text'>$($params.Name)</Value></Eq></Where>"
            $spQuery.Query = $querytext
            $results = $healthRulesList.GetItems($spQuery)
            if ($results.Count -eq 1) {
                $item = $results[0]

                $item["HealthRuleCheckEnabled"] = $params.Enabled
                if ($params.ContainsKey("RuleScope")) { $item["HealthRuleScope"] = $params.RuleScope }
                if ($params.ContainsKey("Schedule")) { $item["HealthRuleSchedule"] = $params.Schedule }
                if ($params.ContainsKey("FixAutomatically")) { $item["HealthRuleAutoRepairEnabled"] = $params.FixAutomatically }

                $item.Update()
            } else {
                throw "Could not find specified Health Analyzer Rule. Health Analyzer Rule settings will not be applied"
                return
            }
        } else {
            throw "Could not find Health Analyzer Rules list. Health Analyzer Rule settings will not be applied"
            return
        }
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]  [System.String] $Name,
        [parameter(Mandatory = $true)]  [System.Boolean] $Enabled,
        [parameter(Mandatory = $false)] [ValidateSet("All Servers","Any Server")] [System.String] $RuleScope,
        [parameter(Mandatory = $false)] [ValidateSet("Hourly","Daily","Weekly","Monthly","OnDemandOnly")] [System.String] $Schedule,
        [parameter(Mandatory = $false)] [System.Boolean] $FixAutomatically,
        [parameter(Mandatory = $false)] [System.Management.Automation.PSCredential] $InstallAccount
    )

    Write-Verbose -Message "Testing Health Analyzer rule configuration settings"
    $CurrentValues = Get-TargetResource @PSBoundParameters

    if ($null -eq $CurrentValues) { return $false }

    return Test-SPDSCSpecificParameters -CurrentValues $CurrentValues -DesiredValues $PSBoundParameters
}

Export-ModuleMember -Function *-TargetResource
