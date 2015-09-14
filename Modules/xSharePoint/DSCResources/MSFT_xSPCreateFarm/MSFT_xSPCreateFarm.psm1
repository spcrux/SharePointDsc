function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $FarmConfigDatabaseName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DatabaseServer,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $FarmAccount,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $InstallAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $Passphrase,

        [parameter(Mandatory = $true)]
        [System.String]
        $AdminContentDatabaseName,

        [parameter(Mandatory = $false)]
        [System.UInt32]
        $CentralAdministrationPort
    )

    Write-Verbose -Message "Checking for local SP Farm"

    $result = Invoke-xSharePointCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
        try {
            $spFarm = Invoke-xSharePointSPCmdlet -CmdletName "Get-SPFarm"
        } catch {
            Write-Verbose -Message "Unable to detect local farm."
        }
        
        if ($null -eq $spFarm) {return @{ }}

        $returnValue = @{
            FarmName = $spFarm.Name
        }
        return $returnValue
    }
    return $result
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $FarmConfigDatabaseName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DatabaseServer,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $FarmAccount,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $InstallAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $Passphrase,

        [parameter(Mandatory = $true)]
        [System.String]
        $AdminContentDatabaseName,

        [parameter(Mandatory = $false)]
        [System.UInt32]
        $CentralAdministrationPort
    )
    
    if (-not $PSBoundParameters.ContainsKey("CentralAdministrationPort")) { $PSBoundParameters.Add("CentralAdministrationPort", 9999) }

    $result = Invoke-xSharePointCommand -Credential $InstallAccount -Arguments $PSBoundParameters -ScriptBlock {
        $params = $args[0]

        $newFarmArgs = @{
            DatabaseServer = $params.DatabaseServer
            DatabaseName = $params.FarmConfigDatabaseName
            FarmCredentials = $params.FarmAccount
            AdministrationContentDatabaseName = $params.AdminContentDatabaseName
            Passphrase = (ConvertTo-SecureString -String $params.Passphrase -AsPlainText -force)
            SkipRegisterAsDistributedCacheHost = $true
        }
        
        switch((Get-xSharePointInstalledProductVersion).FileMajorPart) {
            15 {
                Write-Verbose -Message "Detected Version: SharePoint 2013"
            }
            16 {
                Write-Verbose -Message "Detected Version: SharePoint 2016"
                $newFarmArgs.Add("LocalServerRole", "Custom")
            }
            Default {
                throw [Exception] "An unknown version of SharePoint (Major version $_) was detected. Only versions 15 (SharePoint 2013) or 16 (SharePoint 2016) are supported."
            }
        }

        Invoke-xSharePointSPCmdlet -CmdletName "New-SPConfigurationDatabase" -Arguments $newFarmArgs
        Invoke-xSharePointSPCmdlet -CmdletName "Install-SPHelpCollection" -Arguments @{ All = $true }
        Invoke-xSharePointSPCmdlet -CmdletName "Initialize-SPResourceSecurity"
        Invoke-xSharePointSPCmdlet -CmdletName "Install-SPService"
        Invoke-xSharePointSPCmdlet -CmdletName "Install-SPFeature" -Arguments @{ AllExistingFeatures = $true; Force = $true }
        Invoke-xSharePointSPCmdlet -CmdletName "New-SPCentralAdministration" -Arguments @{ Port = $params.CentralAdministrationPort; WindowsAuthProvider = "NTLM" }
        Invoke-xSharePointSPCmdlet -CmdletName "Install-SPApplicationContent"
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $FarmConfigDatabaseName,

        [parameter(Mandatory = $true)]
        [System.String]
        $DatabaseServer,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $FarmAccount,

        [parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]
        $InstallAccount,

        [parameter(Mandatory = $true)]
        [System.String]
        $Passphrase,

        [parameter(Mandatory = $true)]
        [System.String]
        $AdminContentDatabaseName,

        [parameter(Mandatory = $false)]
        [System.UInt32]
        $CentralAdministrationPort
    )

    $result = Get-TargetResource @PSBoundParameters

    if ($result.Count -eq 0) { return $false }
    return $true
}

Export-ModuleMember -Function *-TargetResource
