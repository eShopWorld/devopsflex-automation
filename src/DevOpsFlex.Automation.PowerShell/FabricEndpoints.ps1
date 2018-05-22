﻿class DnsEndpoint {
    [string] $Uri
    [string] $Region

    DnsEndpoint () { }

    [string] GetRegionName()
    {
        switch($this.region) {
            "we" { return "West Europe" }
            "eus" { return "East US" }
            "ase" { return "Australia Southeast" }
            "sea" { return "Southeast Asia" }
            default { throw "Unknown region mapping for: $($this.Region)" }
        }

        throw "Unknown region mapping for: $($this.Region)"
    }
}

function New-FabricEndPoint
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

    $dnsEndpoints = @()

    foreach($lb in $lbs) {

        ### MOVE THIS INTO IT'S OWN THING
        # Find the Configuration / DNS record settings
        $lb.Name -match '\w*-(\w*)-\w*-(\w*)-\w*-\w*' > $null
        $region = $Matches[1]
        $configuration = $Matches[2]

        switch($configuration)
        {
            "sand" { $dnsConfiguration = "sandbox" }
            "pprod" { $dnsConfiguration = "preprod" }
            default { $dnsConfiguration = $configuration }
        }

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

        $dnsRoot = "$dnsConfiguration.eshopworld.$dnsSuffix"

        $existingDns = Get-AzureRmDnsRecordSet -Name "$dnsName" `
                                               -RecordType A `
                                               -ZoneName $dnsRoot `
                                               -ResourceGroupName "global-platform-$configuration" `
                                               -ErrorAction SilentlyContinue

        if(($existingDns -ne $null) -and $Force.IsPresent) {
            $existingDns | Remove-AzureRmDnsRecordSet -Confirm:$False -Overwrite
            $existingDns = $null
        }

        if($existingDns -eq $null) {
            New-AzureRmDnsRecordSet -Name "$dnsName" `
                                    -RecordType A `
                                    -ZoneName $dnsRoot `
                                    -ResourceGroupName "global-platform-$configuration" `
                                    -Ttl 360 `
                                    -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$pip") > $null
        }

        if(-not $UseSsl.IsPresent) {
            $dnsEndpoints += [DnsEndpoint]@{Uri = "$dnsName.$dnsRoot";
                                            Region = $region;}
        }

        try { $probe = ($lb.Probes | ? { $_.Name -eq $Name })[0] } catch {}

        if($probe -and $Force.IsPresent) {
            $lb | Remove-AzureRmLoadBalancerProbeConfig -Name $probe.Name | Set-AzureRmLoadBalancer > $null
            $probe = $null
        }
        $lbRefresh = (Get-AzureRmLoadBalancer -Name $lb.Name -ResourceGroupName $lb.ResourceGroupName)

        if($probe -eq $null) {
            $lbRefresh | Add-AzureRmLoadBalancerProbeConfig -Name "$Name" `
                                                            -Protocol Http `
                                                            -Port $Port `
                                                            -RequestPath $ProbePath `
                                                            -IntervalInSeconds 30 `
                                                            -ProbeCount 2 > $null
            $lbRefresh | Set-AzureRmLoadBalancer > $null
            $lbRefresh = (Get-AzureRmLoadBalancer -Name $lb.Name -ResourceGroupName $lb.ResourceGroupName)
        }

        try { $rule = ($lb.LoadBalancingRules | ? { $_.Name -eq $Name })[0] } catch {}

        if($rule -and $Force.IsPresent) {
            $lbRefresh | Remove-AzureRmLoadBalancerRuleConfig -Name $rule.Name | Set-AzureRmLoadBalancer > $null
            $rule = $null
        }
        $lbRefresh = (Get-AzureRmLoadBalancer -Name $lb.Name -ResourceGroupName $lb.ResourceGroupName)

        if($rule -eq $null) {
            $lbRefresh | Add-AzureRmLoadBalancerRuleConfig -Name "$Name" `
                                                           -Protocol Tcp `
                                                           -ProbeId ($lbRefresh.Probes | ? { $_.Name -eq $Name})[0].Id `
                                                           -FrontendPort $Port `
                                                           -BackendPort $Port `
                                                           -FrontendIpConfigurationId $lbRefresh.FrontendIpConfigurations[0].Id `
                                                           -BackendAddressPoolId $lbRefresh.BackendAddressPools[0].Id > $null
            $lbRefresh | Set-AzureRmLoadBalancer > $null
        }
    }

    Write-Host 'Done with LBs'

    if($UseSsl.IsPresent) {
        $appGateways = Get-AzureRmApplicationGateway

        foreach($ag in $appGateways) {

            ### MOVE THIS INTO IT'S OWN THING

            $ag.Name -match '\w*-(\w*)-\w*-(\w*)-\w*' > $null
            $region = $Matches[1]
            $configuration = $Matches[2]

            switch($configuration)
            {
                "sand" { $dnsConfiguration = "sandbox" }
                "pprod" { $dnsConfiguration = "preprod" }
                default { $dnsConfiguration = $configuration }
            }

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

            if(($ag.FrontendPorts | ? { $_.Port -eq 443 }).Count -eq 0) {
                $ag | Add-AzureRmApplicationGatewayFrontendPort -Name 'https-port' -Port 443 | Set-AzureRmApplicationGateway > $null
            }

            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            # Find the public IP address of the app gateway
            $pipRes = Get-AzureRmResource -ResourceId ($ag.FrontendIPConfigurations[0].PublicIPAddress.Id)
            $pip = (Get-AzureRmPublicIpAddress -Name $pipRes.ResourceName -ResourceGroupName $pipRes.ResourceGroupName).IpAddress

            $dnsRoot = "$dnsConfiguration.eshopworld.$dnsSuffix"

            $existingDns = Get-AzureRmDnsRecordSet -Name "$dnsName" `
                                                   -RecordType A `
                                                   -ZoneName $dnsRoot `
                                                   -ResourceGroupName "global-platform-$configuration" `
                                                   -ErrorAction SilentlyContinue

            if(($existingDns -ne $null) -and $Force.IsPresent) {
                $existingDns | Remove-AzureRmDnsRecordSet -Confirm:$False -Overwrite  > $null
                $existingDns = $null
            }

            if($existingDns -eq $null) {
                New-AzureRmDnsRecordSet -Name "$dnsName" `
                                        -RecordType A `
                                        -ZoneName $dnsRoot `
                                        -ResourceGroupName "global-platform-$configuration" `
                                        -Ttl 360 `
                                        -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$pip") > $null
            }

            $dnsEndpoints += [DnsEndpoint]@{Uri = "$dnsName.$dnsRoot";
                                            Region = $region;}

            try { $agProbe = ($ag.Probes | ? { $_.Name -eq $Name })[0] } catch {}

            if($agProbe -and $Force.IsPresent) {
                $agRefresh | Remove-AzureRmApplicationGatewayProbeConfig -Name $agProbe.Name | Set-AzureRmApplicationGateway > $null
                $agProbe = $null
            }
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            if($agProbe -eq $null) {
                $agRefresh | Add-AzureRmApplicationGatewayProbeConfig -Name "$Name" `
                                                               -Protocol Http `
                                                               -HostName "$dnsName-lb.$dnsConfiguration.eshopworld.$dnsSuffix" `
                                                               -Path "$ProbePath" `
                                                               -Interval 30 `
                                                               -Timeout 120 `
                                                               -UnhealthyThreshold 2 > $null
                $agRefresh | Set-AzureRmApplicationGateway > $null
                $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName
            }

            try { $listener = ($ag.HttpListeners | ? { $_.Name -eq $Name })[0] } catch {}

            if($listener -and $Force.IsPresent) {
                $agRefresh | Remove-AzureRmApplicationGatewayHttpListener -Name $listener.Name | Set-AzureRmApplicationGateway > $null
                $listener = $null
            }
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            if($listener -eq $null) {
                $agRefresh | Add-AzureRmApplicationGatewayHttpListener -Name "$Name" `
                                                                       -Protocol "Https" `
                                                                       -SslCertificate ($agRefresh.SslCertificates | ? { $_.Name -eq "star.$dnsConfiguration.eshopworld.$dnsSuffix" })[0] `
                                                                       -FrontendIPConfiguration ($agRefresh.FrontendIPConfigurations)[0] `
                                                                       -FrontendPort ($agRefresh.FrontendPorts | ? { $_.Port -eq 443 })[0] `
                                                                       -HostName "$dnsName.$dnsConfiguration.eshopworld.$dnsSuffix" > $null
                $agRefresh | Set-AzureRmApplicationGateway > $null
                $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName
            }

            try { $httpSetting = ($ag.BackendHttpSettingsCollection | ? { $_.Name -eq $Name })[0] } catch {}

            if($httpSetting -and $Force.IsPresent) {
                $agRefresh | Remove-AzureRmApplicationGatewayBackendHttpSettings -Name $httpSetting.Name | Set-AzureRmApplicationGateway > $null
                $httpSetting = $null
            }
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            if($httpSetting -eq $null) {
                $agRefresh | Add-AzureRmApplicationGatewayBackendHttpSettings -Name "$Name" `
                                                                              -Port $Port `
                                                                              -Protocol "HTTP" `
                                                                              -Probe ($agRefresh.Probes | ? { $_.Name -eq $Name})[0] `
                                                                              -CookieBasedAffinity "Disabled" > $null
                $agRefresh | Set-AzureRmApplicationGateway > $null
                $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName
            }

            try { $agRule = ($ag.RequestRoutingRules | ? { $_.Name -eq $Name })[0] } catch {}

            if($agRule -and $Force.IsPresent) {
                $agRefresh | Remove-AzureRmApplicationGatewayRequestRoutingRule -Name $agRule.Name | Set-AzureRmApplicationGateway > $null
                $agRule = $null
            }
            $agRefresh = Get-AzureRmApplicationGateway -Name $ag.Name -ResourceGroupName $ag.ResourceGroupName

            if($agRule -eq $null) {
                $agRefresh | Add-AzureRmApplicationGatewayRequestRoutingRule -Name $Name `
                                                                             -RuleType Basic `
                                                                             -BackendHttpSettings ($agRefresh.BackendHttpSettingsCollection | ? { $_.Name -eq $Name })[0] `
                                                                             -HttpListener ($agRefresh.HttpListeners | ? { $_.Name -eq $Name })[0] `
                                                                             -BackendAddressPool ($agRefresh.BackendAddressPools)[0] > $null
                $agRefresh | Set-AzureRmApplicationGateway > $null
            }
        }

        Write-Host 'Done with AGs'
    }

    if($dnsEndpoints.Count -gt 0) {
        if($UseSsl.IsPresent) {
            $tmPort = 443
            $monitorProtocol = "HTTPS"
        }
        else {
            $tmPort = $Port
            $monitorProtocol = "HTTP"
        }

        $profile = New-AzureRmTrafficManagerProfile -Name $Name `
                                                    -ResourceGroupName "global-platform-$configuration" `
                                                    -TrafficRoutingMethod Performance `
                                                    -RelativeDnsName "esw-$Name-$configuration" `
                                                    -Ttl 30 `
                                                    -MonitorProtocol $monitorProtocol `
                                                    -MonitorPort $tmPort `
                                                    -MonitorPath $ProbePath `
                                                    -MonitorIntervalInSeconds 10 `
                                                    -MonitorTimeoutInSeconds 9 `
                                                    -MonitorToleratedNumberOfFailures 2

        foreach($endpoint in $dnsEndpoints) {
            $profile | Add-AzureRmTrafficManagerEndpointConfig -EndpointName "$($endpoint.Region)-endpoint" `
                                                               -Type ExternalEndpoints `
                                                               -Target $endpoint.Uri `
                                                               -EndpointLocation $endpoint.GetRegionName() `
                                                               -EndpointStatus Enabled > $null
        }

        $profile | Set-AzureRmTrafficManagerProfile > $null
    }

    Write-Host 'Done with TM'
    Write-Host 'Done with everything'
}
