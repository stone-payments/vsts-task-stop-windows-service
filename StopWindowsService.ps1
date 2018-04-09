[CmdletBinding()]
param([switch]$dotSourceOnly)

# 0 (zero) is an invalid PID returned by ServiceProcess class because is the .net int default value.
$INVALID_PID = 0
function Stop-WindowsService($serviceName, $timeout) {
    try{
        Trace-VstsEnteringInvocation $MyInvocation

        $status = "Stopped"
        $service = Get-Service $serviceName
        Stop-Service $service -Force

        Write-Host "Stop timeout: $timeout"
        $service.WaitForStatus($status, $timeout) | Out-Null
    }finally{
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Get-ServiceProcessId($serviceName){
    try {
        Trace-VstsEnteringInvocation $MyInvocation

        $service = Get-Service $serviceName
        $serviceObject = New-Object -TypeName "System.Management.ManagementObject" -ArgumentList "Win32_service.Name='$($service.name)'"
        $servicePid = $serviceObject.GetPropertyValue("ProcessId")
        return $servicePid
    }
    finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Test-ServiceExists($serviceName) {
    Trace-VstsEnteringInvocation $MyInvocation
    try{
        $service = Get-Service $serviceName
        Write-Host "Service $($service.name) was found."
        return $True
    }catch{
        return $False
    }finally{
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Main () {
    Trace-VstsEnteringInvocation $MyInvocation
    try {

        # Read form input.
        $serviceName = Get-VstsInput -Name "ServiceName" -Require
        $shouldKillService = Get-VstsInput -Name "KillService" -Require -AsBool
        $timeout = Get-VstsInput -Name "Timeout" -Require
        $SkipWhenServiceDoesNotExists = Get-VstsInput -Name "SkipWhenServiceDoesNotExists" -Require -AsBool
        
        # Converting seconds to timespan
        $stopTimeout = (New-TimeSpan -Seconds $timeout).ToString()

        # Whether abort when service not found.
        if(-not (Test-ServiceExists $serviceName)){
            
            if($SkipWhenServiceDoesNotExists){
                Write-Host "The service $serviceName does not exist. Skipping this task."
                return
            }else{
                throw "The service $serviceName does not exist. Please check the service name on the task configuration. If it is the first install and you wish to continue the deploy please check the skip checkbox on the advanced tab."
            }            
        }

        # Get service process PID before try stop it to ensure wmi return non-zero value (basically avoid wmi bug).
        $servicePid = Get-ServiceProcessId $serviceName

        # Try stop service gracefully.
        try {
            Stop-WindowsService -serviceName $serviceName -timeout $stopTimeout
        } catch {
            Write-Output "Error stopping service."            
            Write-Debug $_
        }

        # Check if service process exited.
        if($servicePid -ne $INVALID_PID -and (Get-Process -Id $servicePid -ErrorAction SilentlyContinue)){
            $processStillRunning = $true
        }

        # Service process still alive.
        if($processStillRunning){
            if($shouldKillService) {
                Write-Host "Service Process PID:$servicePid still running, killing it..."
                Stop-Process -Id $servicePid -Force -ErrorAction Continue
                Write-Host "Process of the service $serviceName killed."
            } else {
                throw "The service $serviceName could not be stopped and kill service option was disabled."
            }
        }
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

if($dotSourceOnly -eq $false){
    Main
}
