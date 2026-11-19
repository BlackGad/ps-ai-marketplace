param([string]$InstallFixtureHome)
function Get-InstallHome { $InstallFixtureHome }
function Get-InstallSourceText { throw 'No network in tests' }
function Ensure-InstallPowerShell { $true }
function Test-InstallCommandAvailable { $true }
function claude { 'fixture-version' }
function codex { 'fixture-version' }
function copilot { 'fixture-version' }
