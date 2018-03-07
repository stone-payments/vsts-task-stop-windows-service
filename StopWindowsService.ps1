[CmdletBinding()]
param([switch]$dotSourceOnly)

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


function Get-ServiceProcess($serviceName){
    try {
        Trace-VstsEnteringInvocation $MyInvocation

        $servicePid = Get-ServiceProcessId($serviceName)
        # 0 (zero) is an invalid PID returned because is the .net int default value.
        if($servicePid -ne 0) {
            $ServiceProcess = Get-Process -Id $servicePid
            return $ServiceProcess
        }else{
            throw "Process PID cannot be 0"
        }    
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

function Test-ServiceProcessStopped($serviceName){
    try{
        Trace-VstsEnteringInvocation $MyInvocation

        Get-ServiceProcess $serviceName
        return $False
    }catch{
        Write-Debug $_
        return $True
    } finally{
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
        $shouldKillService = Get-VstsInput -Name "KillService" -Require
        $timeout = Get-VstsInput -Name "Timeout" -Require
        $SkipWhenServiceDoesNotExists = Get-VstsInput -Name "SkipWhenServiceDoesNotExists" -Require
        
        # Whether abort when service not found.
        if(-not (Test-ServiceExists $serviceName)){
            
            if($SkipWhenServiceDoesNotExists){
                Write-Host "The service $serviceName does not exist. Skipping this task."
                return
            }else{
                throw "The service $serviceName does not exist. Please check the service name on the task configuration."
            }            
        }

        # Try stop service gracefully.
        try {
            Stop-WindowsService -serviceName $serviceName -timeout $timeout
        } catch {
            Write-Output "Error stopping service."            
            Write-Debug $_
        }
        
        # Check if service process exited.
        if(Test-ServiceProcessStopped $serviceName){
            Write-Host "Service $serviceName stopped successfully."
            return
        }

        # Service process still alive.
        if($shouldKillService) {
            # Forcedly kill process.
            $servicePid = Get-ServiceProcessId $serviceName            
            Write-Host "Process $servicePid still running, killing it..."        
            Stop-Process $servicePid -Force
            Write-Host "Process of the service $serviceName killed."
            return
        }else{
            throw "The service $serviceName could not be stopped and kill service option was disabled."
        }
    } finally {
        Trace-VstsLeavingInvocation $MyInvocation
    }
}

if($dotSourceOnly -eq $false){
    Main
}
