# Preboot is meant to be run on the Windows' first startup.
# It will register a Scheduled Task to run the main script on login.
# However, Task Scheduler is bugged and will not run the script on the first login.
# TODO: Find a workaround for this issue.

$ProgressTitle = "PowerExpressGUI Bootstrapper"
$TaskName = "PowerExpressGUI"
$TaskDesc = "Runs a PowerShell script that automatically launches PowerExpressGUI on login."

Write-Progress -Activity $ProgressTitle -Status "Registering ScheduledTask"

# Creates a Scheduled Task to run our script at startup

# Here we define the action to take when it is time for our scheduled task to run.
# Actions are the commands that the task will run.
$Action = New-ScheduledTaskAction `
    -Execute 'powershell' `
    -Argument '-ExecutionPolicy Bypass -NoExit -Command "Invoke-RestMethod https://github.com/SapphSky/PowerExpressGUI/raw/main/main.ps1 | Invoke-Expression"'

# Here we define the trigger that will start our scheduled task.
# Triggers are the events that start the task.
$Trigger = New-ScheduledTaskTrigger `
    -AtLogon

# Here we define the principal that will run our scheduled task.
# Principals are the security context that the task runs under.
$Principal = New-ScheduledTaskPrincipal `
    -GroupId 'Administrators' `
    -RunLevel Highest

# Here we define the settings for our scheduled task.
# Settings include things like whether the task can be run on battery power.
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -StartWhenAvailable `
    -DontStopIfGoingOnBatteries `

# Now we can register our scheduled task using the parameters we defined above.
Register-ScheduledTask `
    -TaskName $TaskName `
    -Description $TaskDesc `
    -Action $Action `
    -Principal $Principal `
    -Settings $Settings `
    -Trigger $Trigger `
    -Force

# Check if the task was registered successfully
$Task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($Task) {
    Write-Progress -Activity $ProgressTitle -Status "Completed!"
    Start-Sleep -Seconds 1
}
else {
    Write-Progress -Activity $ProgressTitle -Status "Error: Failed to register task."
    
    # Lets display an error in case our task does not register. This is useful for debugging.
    # You can use the taskschd command to open Task Scheduler and see what went wrong.
    Start-Process "powershell" -Verb RunAs -Wait -ArgumentList "-NoExit -Command 'echo PowerExpressGUI ran into an error. Use this terminal to debug, or close and continue the installation like normal.'"
}
