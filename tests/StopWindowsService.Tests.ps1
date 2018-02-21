# Find and import source script.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$systemUnderTest = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
$srcDir = "$here\.."
. "$srcDir\$systemUnderTest" -dotSourceOnly

# Import vsts sdk.
$vstsSdkPath = Join-Path $PSScriptRoot ..\ps_modules\VstsTaskSdk\VstsTaskSdk.psm1 -Resolve
Import-Module -Name $vstsSdkPath -Prefix Vsts -ArgumentList @{ NonInteractive = $false } -Force

Describe "Main" {
    # General mocks needed to control flow and avoid throwing errors.
    Mock Trace-VstsEnteringInvocation -MockWith {}
    Mock Trace-VstsLeavingInvocation -MockWith {}

    Context "Input validation" {
        Mock Get-VstsInput -MockWith { return "" }
        Mock New-Item -MockWith {}
        
        It "Given empty ServiceName, task should be aborted" {
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return "killornot" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_timeout" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "some_action" }
            # Force input read to return empty string.
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "" }
            # Call function expecting exception.
            { Main } | Should -Throw "Required parameter 'ServiceName' cannot be empty."
        }

        It "Given empty KillService parameter, task should be aborted" {
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_sn" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_timeout" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "some_action" }
            # Force input read to return empty string.
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return "" }
            # Call function expecting exception.
            { Main } | Should -Throw "Required parameter 'KillService' cannot be empty."
        }

        It "Given empty Timeout parameter, task should be aborted" {
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_sn" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return "some_ks" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "some_action" }
            # Force input read to return empty string.
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "" }
            # Call function expecting exception.
            { Main } | Should -Throw "Required parameter 'Timeout' cannot be empty."
        }

        It "Given empty SkipWhenServiceDoesNotExists parameter, task should be aborted" {
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_sn" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return "some_ks" }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return "some_timeout" }
            # Force input read to return empty string.
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "" }
            # Call function expecting exception.
            { Main } | Should -Throw "Required parameter 'SkipWhenServiceDoesNotExists' cannot be empty."
        }
    }
}

