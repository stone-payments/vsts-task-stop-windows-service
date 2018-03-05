[CmdletBinding()]
param([switch]$dotSourceOnly)
function Stop-WindowsService($serviceName, $timeout) {
    $status = "Stopped"
    $service = Get-Service $serviceName
    Stop-Service $service -Force
    try{
        Write-Host "Stop timeout: $timeout"
        $service.WaitForStatus($status, $timeout) | Out-Null
        return $True
    }catch{
        Write-Host "Timeout reached."            
        Write-Debug $_
        return $False
    }
}

function Kill-WindowsService ($serviceName) {
    $service = Get-Service $serviceName
    $serviceObject = New-Object -TypeName "System.Management.ManagementObject" -ArgumentList "Win32_service.Name='$($service.name)'"
    $serviceObject
    $servicePid = $serviceObject.GetPropertyValue("ProcessId")
    if($servicePid -ne 0) {
        if(Get-Process -Id $servicePid){
            Write-Host "Process $servicePid still running, killing it..."
            Stop-Process $servicePid -Force
        }
        Write-Host "Service $serviceName killed."
    }else{
        Write-Host "[Kill-WindowsService] Process not found for service $serviceName."
    }
}

function Test-ServiceExists($serviceName) {
    
    try{
        $service = Get-Service $serviceName
        Write-Host "Service $($service.name) was found."
        return $True
    }catch{
        return $False
    }
}
function Main () {
    # For more information on the VSTS Task SDK:
    # https://github.com/Microsoft/vsts-task-lib
    Trace-VstsEnteringInvocation $MyInvocation
    try {
        
        $serviceName = Get-VstsInput -Name "ServiceName" -Require
        $shouldKillService = Get-VstsInput -Name "KillService" -Require
        $timeout = Get-VstsInput -Name "Timeout" -Require
        $SkipWhenServiceDoesNotExists = Get-VstsInput -Name "SkipWhenServiceDoesNotExists" -Require
               
        if(-not (Test-ServiceExists $serviceName)){
            
            if($SkipWhenServiceDoesNotExists){
                Write-Host "The service $serviceName does not exist. Skipping this task."
                return
            }else{
                throw "The service $serviceName does not exist. Please check the service name on the task configuration."
            }            
        }

        $serviceStopped = Stop-WindowsService -serviceName $serviceName -timeout $timeout
            
        if($serviceStopped){
            Write-Host "Service $serviceName stopped successfully."
        }else{
            if($shouldKillService){                    
                Kill-WindowsService $serviceName
            }else{
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
