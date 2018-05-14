﻿function New-FabricEndPoint
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true, Position=0)]
        [string] $Name,

        [parameter(Mandatory=$true, Position=1)]
        [int] $Port,

        [parameter(Mandatory=$false)]
        [string] $ProbePath = "/Probe",

        [switch] $UseSsl,

        [switch] $Force
    )

    if($UseSsl.IsPresent) {
        $lbs = Get-AzureRmLoadBalancer | ? { $_.Name.ToLower() -match '-ilb' }
        $dnsLayerSuffix = "-lb"
    }
    else {
        $lbs = Get-AzureRmLoadBalancer | ? { $_.Name.ToLower() -match '-lb' }
        $dnsLayerSuffix = ""
    }

    foreach($lb in $lbs) {
        ### MOVE THIS INTO IT'S OWN THING
        # Find the Configuration / DNS record settings
        $lb.Name -match '\w*-(\w*)-\w*-(\w*)-\w*-\w*' > $null
        $region = $Matches[1]
        $configuration = $Matches[2]

        if($configuration -eq 'prod' -or $configuration -eq 'sand') {
            $dnsSuffix = 'com'
        }
        else {
            $dnsSuffix = 'net'
        }

        if($lbs.Count -gt 1) {
            $dnsName = "$Name-$region$dnsLayerSuffix"
        }
        else {
            $dnsName = "$Name$dnsLayerSuffix"
        }
        ###

        # Find the public IP address of the load balancer
        if($UseSsl.IsPresent) {
            $pip = ($lb.FrontendIpConfigurations)[0].PrivateIpAddress
        }
        else {
            $pipRes = Get-AzureRmResource -ResourceId ($lb.FrontendIpConfigurations[0].PublicIpAddress.Id)
            $pip = (Get-AzureRmPublicIpAddress -Name $pipRes.ResourceName -ResourceGroupName $pipRes.ResourceGroupName).IpAddress
        }

        New-AzureRmDnsRecordSet -Name "$dnsName" `
                                -RecordType A `
                                -ZoneName "$configuration.eshopworld.$dnsSuffix" `
                                -ResourceGroupName "global-platform-$configuration" `
                                -Ttl 360 `
                                -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$pip") > $null

        $lb | Add-AzureRmLoadBalancerProbeConfig -Name "$Name" `
                                                -Protocol Http `
                                                -Port $Port `
                                                -RequestPath $ProbePath `
                                                -IntervalInSeconds 30 `
                                                -ProbeCount 2 > $null
        $lb | Set-AzureRmLoadBalancer > $null
        $lbRefresh = (Get-AzureRmLoadBalancer -Name $lb.Name -ResourceGroupName $lb.ResourceGroupName)

        $lbRefresh | Add-AzureRmLoadBalancerRuleConfig -Name "$Name" `
                                               -Protocol Tcp `
                                               -ProbeId ($lbRefresh.Probes | ? { $_.Name -match $Name})[0].Id `
                                               -FrontendPort $Port `
                                               -BackendPort $Port `
                                               -FrontendIpConfigurationId $lbRefresh.FrontendIpConfigurations[0].Id `
                                               -BackendAddressPoolId $lbRefresh.BackendAddressPools[0].Id > $null
        $lbRefresh | Set-AzureRmLoadBalancer > $null
    }

    Write-Host 'Done with LBs'

    if($UseSsl.IsPresent) {
        $appGateways = Get-AzureRmApplicationGateway

        foreach($ag in $appGateways) {

            ### MOVE THIS INTO IT'S OWN THING
            $ag.Name -match '\w*-(\w*)-\w*-(\w*)-\w*' > $null
            $region = $Matches[1]
            $configuration = $Matches[2]

            if($configuration -eq 'prod' -or $configuration -eq 'sand') {
                $dnsSuffix = 'com'
            }
            else {
                $dnsSuffix = 'net'
            }

            if($lbs.Count -gt 1) {
                $dnsName = "$Name-$region"
            }
            else {
                $dnsName = "$Name"
            }
            ###

            ### MISSING THE PORT CHECK -> ADD THIS AFTER THIS THING ACTUALLY WORKS!
            # $ag | Add-AzureRmApplicationGatewayFrontendPort -Name https-port -Port 443 | Set-AzureRmApplicationGateway

            # Find the public IP address of the app gateway
            $pipRes = Get-AzureRmResource -ResourceId ($ag.FrontendIPConfigurations[0].PublicIPAddress.Id)
            $pip = (Get-AzureRmPublicIpAddress -Name $pipRes.ResourceName -ResourceGroupName $pipRes.ResourceGroupName).IpAddress

            New-AzureRmDnsRecordSet -Name "$dnsName" `
                                    -RecordType A `
                                    -ZoneName "$configuration.eshopworld.$dnsSuffix" `
                                    -ResourceGroupName "global-platform-$configuration" `
                                    -Ttl 360 `
                                    -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$pip") > $null

            $ag | Add-AzureRmApplicationGatewayProbeConfig -Name "$Name" `
                                                           -Protocol Http `
                                                           -HostName "$dnsName-ilb" `
                                                           -Path "$ProbePath" `
                                                           -Interval 30 `
                                                           -Timeout 120 `
                                                           -UnhealthyThreshold 2
            $ag | Set-AzureRmApplicationGateway
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            $agRefresh | Add-AzureRmApplicationGatewayHttpListener -Name "$Name" `
                                                                   -Protocol "Https" `
                                                                   -SslCertificate ($agRefresh.SslCertificates | ? { $_.Name -match "star.eshopworld.net" })[0] `
                                                                   -FrontendIPConfiguration ($agRefresh.FrontendIPConfigurations)[0] `
                                                                   -FrontendPort ($agRefresh.FrontendPorts | ? { $_.Port -eq 443 })[0] `
                                                                   -HostName "$dnsName.$configuration.eshopworld.$dnsSuffix"
            $agRefresh | Set-AzureRmApplicationGateway
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            $agRefresh | Add-AzureRmApplicationGatewayBackendHttpSettings -Name "$Name" `
                                                                          -Port $Port `
                                                                          -Protocol "HTTP" `
                                                                          -Probe ($agRefresh.Probes | ? { $_.Name -match $Name})[0] `
                                                                          -CookieBasedAffinity "Disabled"
            $agRefresh | Set-AzureRmApplicationGateway
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            $agRefresh | Add-AzureRmApplicationGatewayRequestRoutingRule -Name $Name `
                                                                         -RuleType Basic `
                                                                         -BackendHttpSettings ($agRefresh.BackendHttpSettingsCollection | ? { $_.Name -match $Name })[0] `
                                                                         -HttpListener ($agRefresh.HttpListeners | ? { $_.Name -match $Name })[0] `
                                                                         -BackendAddressPool ($agRefresh.BackendAddressPools)[0]
            $agRefresh | Set-AzureRmApplicationGateway
        }

        Write-Host 'Done with LBs'
    }

    Write-Host 'Done with everything'
}
