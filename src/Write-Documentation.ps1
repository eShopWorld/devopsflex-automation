Import-Module $PSScriptRoot\DevOpsFlex.Automation.PowerShell\DevOpsFlex.Automation.PowerShell.psd1 -Force -Verbose
New-MarkdownHelp -Module DevOpsFlex.Automation.PowerShell -OutputFolder $PSScriptRoot\..\docs -Force
