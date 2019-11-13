$computers = Get-Content -Path $env:HOMEPATH\Desktop\Wazuh_Devices.txt

$credential = Get-Credential

ForEach ($computer in $computers) 
{
	#Check to see if the computer responds to a ping.
	if (Test-Connection $computer -Quiet -Count 1 -BufferSize 1 -ErrorAction SilentlyContinue)
	{
		Write-host "$computer responds to ping" -ForegroundColor Cyan
		
		#Check to see if the computer is WinRM enabled.
		if((Invoke-Command -ComputerName $computer -Credential $credential -ScriptBlock{return "Hello"}) -eq "Hello")
		{
			Write-host "WinRM is enabled on $computer" -ForegroundColor Cyan
	
			#On the remote machine, map a non-persistent network drive to the file share hosting the installer, and then download the installer from that network drive.
			Invoke-Command -ComputerName $computer -ErrorAction SilentlyContinue -Credential $credential -ArgumentList $credential -Scriptblock `
			{
				$credential = $args[0]
	
				#New-PSDrive -Name "R" -Root \\ccc-iem\deployment\wazuh -PSProvider FileSystem -Credential $credential|out-null
				net use R: \\ccc-iem\deployment\wazuh /user:$credential.username $credential.getnetworkcredential().password
				Copy-Item -Path "R:\wazuh-agent.msi" -Destination "C:\'Program Files'" -Force
			}
			
			#Run winrs on the local system to command the remote computer to run the installer it downloaded.
			winrs /r:$computer /env:"Program Files" "wazuh-agent.msi /q ADDRESS='10.249.0.252' AUTHD_SERVER='10.249.0.252'"
			#sleep 30
	
			#Run shutdown commands 'locally' on the computer via WinRM, so it has a lower chance of ignoring remote shutdown.
			#Invoke-Command -ComputerName $computer -ErrorAction SilentlyContinue -Credential $credential -Scriptblock `
			#{
			#	shutdown /r /t 0
			#	restart-computer -force
			#}
	
			#Wait until the computer stops responding to pings, then watch for it to come back up.
			#while(Test-Connection $computer -count 1 -buffer 1 -quiet -erroraction silentlycontinue)
			#{
			#	Write-Host "$computer hasn't begun rebooting yet. Sleeping 5 seconds."
	        #
			#	sleep 5
			#}
	
			#Watch for the remote computer to respond to pings again after rebooting.
			#while(!(Test-Connection $computer -count 1 -buffer 1 -quiet -erroraction silentlycontinue))
			#{   
			#	Write-Host "$computer hasn't finished rebooting yet. Sleeping 60 seconds."
	        #
			#	sleep 60
			#}
	
			#Run winrs on the local system to command the remote system to run the installer it downloaded again, with a different set of parameters.
			#winrs -r:$computer C:\ProgramData\wazuh-agent.msi /q ADDRESS='10.249.0.252' AUTHD_SERVER='10.249.0.252'
			#sleep 10
		
			#Check to see if the installer ran successfully.
			Invoke-Command -ComputerName $computer -ErrorAction SilentlyContinue -Credential $credential -ArgumentList $credential -Scriptblock `
			{
				$hostname = hostname
				if(Test-Path -Path "C:\'Program Files (x86)'\ossec-agent" or (Test-Path -Path "C:\'Program Files'\ossec-agent"))
				{
					Write-Host -ForegroundColor Cyan "Wazuh path detected on $hostname. Please check remote console for verification"
				
					if((get-service|?{$_.path -match "Wazuh"}).count -eq 1)
					{
						write-host "Wazuh Service Detected on $hostname!" -ForegroundColor cyan
                        write-host "Restarting Wazuh Service" -ForegroundColor cyan
                        Restart-Service -Name Wazuh
					}
				} `
				else `
				{
					Write-Host -ForegroundColor Yellow "Wazuh path not detected on $hostname. Please re-run script again to attempt install or check Wazuh console for activation status."
				}
			}
		} `
		else `
		{
			Write-Host "$computer isn't WinRM enabled..." -ForegroundColor Yellow
		}
	} `
	else `
	{
		Write-Host "$computer did not respond to a ping..." -ForegroundColor Red -BackgroundColor black
	}
}
