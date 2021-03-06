@{

# Script module or binary module file associated with this manifest.
RootModule = 'DevOpsFlex.Automation.PowerShell.psm1'

# Version number of this module.
ModuleVersion = '1.6.0'

# ID used to uniquely identify this module
GUID = 'a5cc17b4-6372-485d-a61b-3e822010b1bb'

# Author of this module
Author = 'David Rodrigues, Artur Zgodzinski'

# Company or vendor of this module
CompanyName = 'eShopWorld'

# Copyright statement for this module
Copyright = '(c) 2019 . All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell support module for development automation against Windows Azure.'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
ProcessorArchitecture = 'None'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @("AddKeyVaultCert.psm1")

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = ''

# Variables to export from this module
VariablesToExport = ''

# Aliases to export from this module
AliasesToExport = ''

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Automation', 'DevOps', 'Azure', 'ARM', 'ARMTemplates', 'Deployment')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/djfr/devopsflex-automation/blob/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/djfr/devopsflex-automation'

        # A URL to an icon representing this module.
        IconUri = 'https://devopsflexblob.blob.core.windows.net/icons/devopsflex_50_50.png'

        # ReleaseNotes of this module
        ReleaseNotes = 'Added Autorest cmdlet to generate client nuget package for given json url'

        # ExternalModuleDependencies
        ExternalModuleDependencies = @('Azure', 'AzureRM.Profile', 'AzureRM.Resources')

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''
}

