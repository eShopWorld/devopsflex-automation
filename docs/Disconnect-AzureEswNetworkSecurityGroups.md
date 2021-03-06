---
external help file: DevOpsFlex.Automation.PowerShell-help.xml
Module Name: DevOpsFlex.Automation.PowerShell
online version:
schema: 2.0.0
---

# Disconnect-AzureEswNetworkSecurityGroups

## SYNOPSIS
Copies Secrets and Access Policies from a source KeyVault onto a Destination KeyVault.

## SYNTAX

## DESCRIPTION
Copies Secrets and Access Policies from a source KeyVault onto a Destination KeyVault.

You need to be in the right subscription where both KeyVaults are located.
Both source and destination KeyVault need to be on the same subscription.
You need to be loged in azure with 'Login-AzAccount' and you need to have LIST and READ rights on secrets on the target key vault.

## EXAMPLES

### EXAMPLE 1
```
Copy-AzFlexKeyVault -SourceKeyvaultName my-source-kv -SourceResourceGroup my-source-kv-rg -DestinationKeyvaultName my-destination-kv -DestinationResourceGroup my-destination-kv-rg
```

Copies Secrets and Access Policies from the KeyVault my-source-kv in Resource Group my-source-kv-rg to the KeyVault my-destination-kv in Resource Group my-destination-kv-rg.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable.
For more information, see about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
