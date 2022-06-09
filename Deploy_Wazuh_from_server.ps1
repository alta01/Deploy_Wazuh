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

			#On the remote machine, create an object to pull the msi file to the local workstation
			Invoke-Command -ComputerName $computer -ErrorAction SilentlyContinue -Credential $credential -ArgumentList $credential -Scriptblock `
			{
				$credential = $args[0]
				$client = new-object System.Net.WebClient
				$client.DownloadFile("https://packages.wazuh.com/3.x/windows/wazuh-agent-3.10.2-1.msi","C:\tmp\wazuh-agent.msi")
				cmd /c "C:\tmp\wazuh-agent.msi /q ADDRESS='10.249.0.22' AUTHD_SERVER='10.249.0.22'"
			}

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
