#Netscaler Information
$script:username = "nsroot"
$script:password = "nsroot"
$SG = "svg-HTTPTST"
$LB = "vlb-HTTPTST"
$LBPORT = 88


#For testing connectivty
$login = @{
    login = @{
        username = $username;
        password = $password
    }
}
$loginJson = ConvertTo-Json -InputObject $login


#Wait until CPX is up and available
do
{
    write-host "Waiting for CPX to become available"
    Start-Sleep -Seconds 5
    $localip = invoke-restmethod -uri "http://consul:8500/v1/catalog/service/netscalercpx-88" -ErrorAction Continue
    $script:nsip = $localip[0].ServiceAddress

    $testparams = @{
        Uri = "http://$nsip/nitro/v1/config/login"
        Method = 'POST'
        Body = $loginJson
        ContentType = 'application/json'
    }

    Write-host "Testing for AUTH on $nsip"
    try {
        $testrest = Invoke-RestMethod @testparams -ErrorAction Continue
    } catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    }

}UNTIL($testrest.errorcode -eq 0)

write-host "Connecting to CPX at $nsip.."
#Connect to the Netscaler and create session variable
$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)
$script:Session =  Connect-Netscaler -Hostname $nsip -PassThru -Credential $Credential

write-host "Creating Service Group $SG"
New-NSLBServiceGroup -Name $SG -Protocol HTTP -Session $Session -ErrorAction Continue
write-host "Creating LB Virtual Server $LB"
New-NSLBVirtualServer -Name $LB -IPAddress $localip[0].ServiceAddress -ServiceType HTTP -Session $Session -port $LBPORT -ErrorAction Continue
write-host "Getting service info"
$services = invoke-restmethod -uri "http://consul:8500/v1/catalog/service/hostname"|Sort-Object ServiceID -Unique
write-host "Adding Services"
foreach ($service in $services)
{
    write-host "Adding server $($service.ServiceID) at $($service.ServiceAddress)"
    New-NSLBServer -Name $service.ServiceID -IPAddress $service.ServiceAddress -Session $Session -ErrorAction Continue
    write-host "Enabling server $($service.ServiceID)"
    Enable-NSLBServer -Name $service.ServiceID -Force -Session $Session -ErrorAction Continue
    write-host "Adding server $($service.ServiceID) to SG"
    New-NSLBServiceGroupMember -Name $SG -ServerName $service.ServiceID -Session $Session -Port "80" -ErrorAction Continue
}

write-host "Binding $SG to $LB"
Add-NSLBVirtualServerBinding -VirtualServerName $LB -ServiceGroupName $SG -Session $Session -ErrorAction Continue
write-host "Enabling $LB"
Enable-NSLBVirtualServer -Name $LB -Force -Session $Session -ErrorAction Continue
$howmany = Get-NSLBServiceGroupMemberBinding $SG -Session $Session
write-host "Now load balancing $($howmany.count) containers"

while($true)
{
Start-Sleep -Seconds 10
$services = invoke-restmethod -uri "http://consul:8500/v1/catalog/service/hostname"
$nsservices = Get-NSLBServiceGroupMemberBinding $SG -Session $Session
$present = $services|select-object -ExpandProperty serviceid|Sort-Object ServiceID -Unique
$needed = $nsservices|select-object -ExpandProperty servername|Sort-Object servername

        $compares = Compare-Object -ReferenceObject $present -DifferenceObject $needed

            foreach ($compare in $compares)
            {
                switch ($compare.SideIndicator)
                {
                    "<=" {
                        write-HOST "ADD LB SERVER $($compare.InputObject)"
                        $service = $services|where-object {$_.ServiceID -eq $($compare.InputObject)}
                        New-NSLBServer -Name $service.ServiceID -IPAddress $service.ServiceAddress -Session $Session -ErrorAction Continue
                        write-host "Enabling server $($service.ServiceID)"
                        Enable-NSLBServer -Name $service.ServiceID -Force -Session $Session -ErrorAction Continue
                        write-host "Adding server $($service.ServiceID) to SG"
                        New-NSLBServiceGroupMember -Name $SG -ServerName $service.ServiceID -Session $Session -Port "80" -ErrorAction Continue

                    }
                    "=>" {
                        write-HOST "REMOVE LB SERVER $($compare.InputObject)"
                        Remove-NSLBServer -Name $compare.InputObject -Force -Session $Session

                    }
                }
            $howmany = Get-NSLBServiceGroupMemberBinding $SG -Session $Session
            write-host "Now load balancing $($howmany.count) containers"
            }
 } 
