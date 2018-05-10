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

    $lbs | % {
        ### MOVE THIS INTO IT'S OWN THING
        # Find the Configuration / DNS record settings
        $_.Name -match '\w*-(\w*)-\w*-(\w*)-\w*-\w*' > $null
        $region = $Matches[1]
        $configuration = $Matches[2]

        if($configuration -eq 'prod') {
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
        $pipRes = Get-AzureRmResource -ResourceId ($_.FrontendIpConfigurations[0].PublicIpAddress.Id)
        $pip = (Get-AzureRmPublicIpAddress -Name $pipRes.ResourceName -ResourceGroupName $pipRes.ResourceGroupName).IpAddress

        New-AzureRmDnsRecordSet -Name "$dnsName" `
                                -RecordType A `
                                -ZoneName "$configuration.eshopworld.$dnsSuffix" `
                                -ResourceGroupName "global-platform-$configuration" `
                                -Ttl 360 `
                                -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$pip") > $null

        $probeName = "$Name-probe"
        $_ | Add-AzureRmLoadBalancerProbeConfig -Name "$probeName" `
                                                -Protocol Http `
                                                -Port $Port `
                                                -RequestPath $ProbePath `
                                                -IntervalInSeconds 30 `
                                                -ProbeCount 2 > $null
        $_ | Set-AzureRmLoadBalancer > $null

        $probeId = ((Get-AzureRmLoadBalancer -Name $_.Name -ResourceGroupName $_.ResourceGroupName).Probes | ? { $_.Name -match "$Name-probe"})[0].Id
        $_ | Add-AzureRmLoadBalancerRuleConfig -Name "$Name" `
                                               -Protocol Tcp `
                                               -ProbeId $probeId `
                                               -FrontendPort $Port `
                                               -BackendPort $Port `
                                               -FrontendIpConfigurationId $_.FrontendIpConfigurations[0].Id `
                                               -BackendAddressPoolId $_.BackendAddressPools[0].Id > $null
        $_ | Set-AzureRmLoadBalancer > $null
    }

    if($UseSsl.IsPresent) {
        $appGateways = Get-AzureRmApplicationGateway

        $appGateways | % {

            ### MOVE THIS INTO IT'S OWN THING
            $_.Name -match '\w*-(\w*)-\w*-(\w*)-\w*' > $null
            $region = $Matches[1]
            $configuration = $Matches[2]

            if($configuration -eq 'prod') {
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

            # Find the public IP address of the app gateway
            $pipRes = Get-AzureRmResource -ResourceId ($_.FrontendIPConfigurations[0].PublicIPAddress.Id)
            $pip = (Get-AzureRmPublicIpAddress -Name $pipRes.ResourceName -ResourceGroupName $pipRes.ResourceGroupName).IpAddress

            New-AzureRmDnsRecordSet -Name "$dnsName" `
                                    -RecordType A `
                                    -ZoneName "$configuration.eshopworld.$dnsSuffix" `
                                    -ResourceGroupName "global-platform-$configuration" `
                                    -Ttl 360 `
                                    -DnsRecords (New-AzureRmDnsRecordConfig -IPv4Address "$pip") > $null

            $probeName = "$Name-probe"
            $_ | Add-AzureRmApplicationGatewayProbeConfig -Name $probeName `
                                                          -Protocol Http `
                                                          -HostName "$dnsName-ilb" `
                                                          -Path "/Probe" `
                                                          -Interval 30 `
                                                          -Timeout 120 `
                                                          -UnhealthyThreshold 2
            $_ | Set-AzureRmApplicationGateway
        }
    }
}