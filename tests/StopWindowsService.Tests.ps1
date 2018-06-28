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
    $serviceMockName = "some_name"
    $mockTimeout = "30"
    $expectedTimespan = "00:00:30"
    Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return $serviceMockName } 
    Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return $mockTimeout }
    Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return "skip" }
    Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
    Mock Test-ServiceExists -MockWith { return $true }
    Mock Write-Host -MockWith {}
    Mock Stop-WindowsService -MockWith { }
    Mock Get-ServiceProcessId -MockWith { return $false }
    Context "When service exists" {
        # Arrange
        Mock Test-ServiceExists -MockWith { return $true } 

        It "Should try stop it"{
            # Act
            Main

            # Assert
            Assert-MockCalled Stop-WindowsService -ParameterFilter { ($serviceName -eq $serviceMockName) -and ($timeout -eq "00:00:30") }
        }
    }
    # Cannot bind parameter 'Seconds'. Cannot convert value "benis" to type "System.Int32". Error: "Input string was not in a correct format."
    Context "When  convert the timeout from seconds to timespan"{
        It "Given a valid int string, it should convert it"{
            Mock New-TimeSpan {"00:00:30"}
            Main
            Assert-MockCalled New-TimeSpan -ParameterFilter { ($Seconds -eq $mockTimeout) }
        }    

        It "Given an invalid string, it should throw an exception"{
            $invalidString = "invalid_string"
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return $invalidString }
            {Main} | Should -Throw "Cannot process argument transformation on parameter 'Seconds'. Cannot convert value `"$invalidString`" to type `"System.Int32`". Error: `"Input string was not in a correct format.`""
        }    
        
    }


    Context "When fails to stop service gracefullly" {
        Mock Get-Process -MockWith { return $true }
        $expectedPID = -1
        Mock Get-ServiceProcessId -MockWith { return $expectedPID}
        Mock Start-Sleep -MockWith {}
        Mock FailIfProcessStillRunning -MockWith {}
        Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $true }
        Mock Stop-Process -MockWith {}

        It "Given kill flag is true, it should be killed." {
            # Act
            Main

            # Assert
            Assert-MockCalled Stop-Process -ParameterFilter { $Id -eq $expectedPID -and $Force}
        }
    }

    Context "When fails to stop service gracefullly 2" {
        Mock Get-Process -MockWith { return $true }
        $expectedPID = -1
        Mock Get-ServiceProcessId -MockWith { return $expectedPID}
        Mock Start-Sleep -MockWith {}

        It "Given kill flag is false, should throw exception" {
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return $serviceMockName } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            
            # Act & Assert
            { Main } | Should -Throw "The service $serviceMockName could not be stopped and kill service option was disabled."
        }

        It "When the service does not exists on the target machine and the skip flag is enabled, it should succeed showing a message" {
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return $mockTimeout }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return $true }
            Mock Test-ServiceExists -MockWith { return $false } 
            Mock Write-Host -MockWith { }
            # Act
            Main
            # Assert
            Assert-MockCalled Write-Host -ParameterFilter { $Object -eq "The service some_name does not exist. Skipping this task."} -Scope It

        }

        It "When the service does not exist on the target machine and the skip flag is disabled, it should fail and throw an exception"{
            # Arrange
            Mock Get-VstsInput -ParameterFilter { $Name -eq "ServiceName" } -MockWith { return "some_name" } 
            Mock Get-VstsInput -ParameterFilter { $Name -eq "KillService" } -MockWith { return $false }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "Timeout" } -MockWith { return $mockTimeout }
            Mock Get-VstsInput -ParameterFilter { $Name -eq "SkipWhenServiceDoesNotExists" } -MockWith { return $false }
            Mock Test-ServiceExists -MockWith { return $false } 

            # Act
            # Assert
            { Main } | Should -Throw "The service some_name does not exist. Please check the service name on the task configuration."
            
        }
    }
}

Describe "Stop-WindowsService" {
    $serviceName = "MyService"
    $timeout = "30"
    Mock Write-Host -MockWith {}

    It "Should call native ps stop-service" {
        $expectedService = "test_service"
        Mock Get-Service { 
            New-Module -AsCustomObject -ScriptBlock {
                Function WaitForStatus {
                    return @{'ReturnValue'= 0}
                }
                Export-ModuleMember -Variable * -Function *
            }
        }
        
        Mock Stop-Service {}

        Stop-WindowsService $serviceName $timeout

        Assert-MockCalled Stop-Service -ParameterFilter { $Force } -Scope It
    }

    Context "When the service is stopped within timeout" {        
        Mock Get-Service { 
            New-Module -AsCustomObject -ScriptBlock {
                Function WaitForStatus {
                    return @{'ReturnValue'= 0}
                }
                Export-ModuleMember -Variable * -Function *
            }
        }

        Mock Stop-Service {}
                
        It "Should not throw" {            
            {Stop-WindowsService $serviceName $timeout} | Should -Not -Throw 
        }
    }

    Context "When the service cannot be stopped and timeout" {        
        Mock Get-Service { 
            New-Module -AsCustomObject -ScriptBlock {
                Function WaitForStatus {
                    Throw 'Timeout reached.'
                }
                Export-ModuleMember -Variable * -Function *
            }
        }

        Mock Stop-Service {}
                
        It "Should throw" {            
            { Stop-WindowsService $serviceName $timeout } | Should -Throw 'Timeout reached.'
        }
    }
}


Describe "Test-ServiceExists" {
    $serviceName="MyService"
    Context "When the service exist on the machine"{
        Mock Get-Service { @{"name"="MyServiceFullName"}}
        Mock Write-Host {}
        
        It "Should return true"{
            Test-ServiceExists $serviceName | Should -Be $True
        }
        It "Should print a message with the service full name, not the display name"{
            Assert-MockCalled Write-Host -ParameterFilter { $Object -eq "Service MyServiceFullName was found." }
        }
    }

    Context "When the service does NOT exist on the machine"{
        Mock Get-Service { throw "Service not found."}
        It "Should return false"{
            Test-ServiceExists $serviceName | Should -Be $False
        }
    }
}