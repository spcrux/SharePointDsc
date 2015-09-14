[CmdletBinding()]
param()

if (!$PSScriptRoot) # $PSScriptRoot is not defined in 2.0
{
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

$RepoRoot = (Resolve-Path $PSScriptRoot\..\..).Path

$ModuleName = "MSFT_xSPManagedMetaDataServiceApp"
Import-Module (Join-Path $RepoRoot "Modules\xSharePoint\Modules\xSharePoint.Util\xSharePoint.Util.psm1")
Import-Module (Join-Path $RepoRoot "Modules\xSharePoint\DSCResources\$ModuleName\$ModuleName.psm1")

Describe "xSPManagedMetaDataServiceApp" {
    InModuleScope $ModuleName {
        $testParams = @{
            Name = "Managed Metadata Service App"
            ApplicationPool = "SharePoint Service Applications"
            DatabaseServer = "databaseserver\instance"
            DatabaseName = "SP_MMS"
        }

        Context "Validate get method" {
            It "Retrieves the data from SharePoint" {
                Mock Invoke-xSharePointSPCmdlet { return @{} } -Verifiable -ParameterFilter { $CmdletName -eq "Get-SPServiceApplication" -and $Arguments.Name -eq $testParams.Name } -ModuleName "xSharePoint.ServiceApplications"
                Get-TargetResource @testParams
                Assert-VerifiableMocks
            }
        }

        Context "Validate test method" {
            It "Fails when MMS service app doesn't exist" {
                Mock -ModuleName $ModuleName Get-TargetResource { return @{} }
                Test-TargetResource @testParams | Should Be $false
            }
            It "Passes when the app exists and uses the correct app pool" {
                Mock -ModuleName $ModuleName Get-TargetResource { 
                    return @{
                        Name = $testParams.Name
                        ApplicationPool = $testParams.ApplicationPool
                    } 
                } 
                Test-TargetResource @testParams | Should Be $true
            }
            It "Fails when the app exists but uses the wrong app pool" {
                Mock -ModuleName $ModuleName Get-TargetResource { 
                    return @{
                        Name = $testParams.Name
                        ApplicationPool = "wrong pool"
                    } 
                } 
                Test-TargetResource @testParams | Should Be $false
            }
        }

        Context "Validate set method" {
            It "Creates a new service app where none exists" {
                Mock Get-TargetResource { return @{} } -Verifiable
                Mock Invoke-xSharePointSPCmdlet { return @{} } -Verifiable -ParameterFilter { $CmdletName -eq "New-SPMetadataServiceApplication" }
                Mock Invoke-xSharePointSPCmdlet { return @{} } -Verifiable -ParameterFilter { $CmdletName -eq "New-SPMetadataServiceApplicationProxy" }

                Set-TargetResource @testParams

                Assert-VerifiableMocks
            }

            It "Updates an existing service app" {
                Mock Get-TargetResource { return @{ ApplicationPool = "Invalid"} } -Verifiable
                Mock Invoke-xSharePointSPCmdlet { return @{} } -Verifiable -ParameterFilter { $CmdletName -eq "Get-SPServiceApplication" -and $Arguments.Name -eq $testParams.Name } -ModuleName "xSharePoint.ServiceApplications"
                Mock Invoke-xSharePointSPCmdlet { return @{} } -Verifiable -ParameterFilter { $CmdletName -eq "Set-SPMetadataServiceApplication" }
                Mock Invoke-xSharePointSPCmdlet { return @{} } -Verifiable -ParameterFilter { $CmdletName -eq "Get-SPServiceApplicationPool" }

                Set-TargetResource @testParams

                Assert-VerifiableMocks
            }
        }
    }    
}