# Find and import source script.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$systemUnderTest = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$srcDir = "$here\.."
. "$srcDir\$systemUnderTest" -dotSourceOnly

# Import vsts sdk.
$vstsSdkPath = Join-Path $PSScriptRoot ..\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1 -Resolve
Import-Module -Name $vstsSdkPath -Prefix Vsts -ArgumentList @{ NonInteractive = $true } -Force

Describe "Main" {
    # General mocks needed to control flow and avoid throwing errors.
    Mock Trace-VstsEnteringInvocation -MockWith {}
    Mock Trace-VstsLeavingInvocation -MockWith {}

    Context "Input validation" {
        Mock Get-VstsInput -MockWith { return "" }
        Mock New-Item -MockWith {}
        
        It "Given empty ServiceName task should be aborted" {
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return "killornot" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_timeout" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "some_action" }
            # Force input read to return empty string.
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "" }
            # Call function expecting exception.
            { Main } | Should -Throw "Required parameter 'ServiceName' cannot be empty."
        }
    }
}

