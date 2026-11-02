#Requires -Version 5.1
<#
.SYNOPSIS
    Checks that a PREL37 Skillable lab VM is complete and ready for attendees.

.DESCRIPTION
    Run this on the Windows 11 lab VM, in Windows PowerShell 5.1 or PowerShell 7. It is read-only: it leaves
    nothing behind on the VM (its temporary files are deleted), changes nothing in Azure or GitHub, and never
    prints tokens, keys, or kubeconfig contents.

    The expectations come from this repository:
      setup/README.md          "Organizer preparation": tools, versions, bundle, network, C:\terraform state
      setup/fast-track.sh      check_tools, the Backstage preparation, the files `make setup` copies
      setup/bootstrap.sh       the nonempty `lab` outputs that `make setup` requires
      setup/artifact-lock.json Node major version, Backstage revision, Yarn version, pinned application image
      infra/main.tf            every resource the foundation creates, and the settings the guide relies on
    If infra/main.tf or setup/ changes, update the tables at the top of this script to match.

    Sections:
      1  Windows host           WSL, Ubuntu, VS Code and its WSL extension, Edge, Windows Terminal
      2  Foundation state       C:\terraform\terraform.tfstate: the `lab` output, every resource infra/main.tf
                                creates, half-created (tainted) resources, a stale lock, Terraform version
      3  WSL tools              The Linux tools `make setup` and the guide use, plus the snags the lab test found
      4  Lab bundle             ~/prel37/setup bundle files, line endings, pinned Backstage runtime
      5  Network from WSL       Azure sign-in, GitHub, registries, and both cluster API servers
      6  Azure foundation       (needs `az login` in WSL) subscription, clusters, model, identities, roles
      7  Kubernetes foundation  (needs `az login` in WSL) both clusters, Crossplane, Argo CD
      8  Learner setup          Only with -IncludeLearnerSetup: what `make setup`, `make auth`, and the local
                                services leave behind

    Result levels: PASS, WARN (works, but an attendee may hit a snag), FAIL (blocks setup or a module),
    INFO, and SKIP (not checked, with the reason). The exit code is 1 when any check fails, otherwise 0.

    If the script is blocked, run it with:  powershell -ExecutionPolicy Bypass -File .\Test-LabReadiness.ps1
    If it was downloaded, run Unblock-File on it first.

.PARAMETER Distro
    WSL distribution name. Default: the first Ubuntu distribution, otherwise the default distribution.

.PARAMETER StatePath
    The bootstrap Terraform state. Default: C:\terraform\terraform.tfstate.

.PARAMETER LabRoot
    The learner workspace inside WSL, as an absolute Linux path such as /home/labuser/prel37.
    Default: $HOME/prel37.

.PARAMETER ExpectedLabId
    When given, the state's LAB_ID must match it (for example, the Skillable lab instance ID).

.PARAMETER IncludeLearnerSetup
    Also verify the learner setup state: repositories, tokens, platform packages, and local services.

.PARAMETER SkipAzure
    Skip sections 6 and 7 (no `az` or `kubectl` calls).

.PARAMETER SkipKubernetes
    Skip section 7 only.

.PARAMETER AzureTimeoutSeconds
    Time limit for each batch of Azure or Kubernetes calls. Default: 240.

.PARAMETER ReportPath
    Also write the results to this text file.

.PARAMETER Json
    Write the results as JSON instead of colored text.

.EXAMPLE
    .\Test-LabReadiness.ps1
    Checks everything that must be ready before an attendee starts.

.EXAMPLE
    .\Test-LabReadiness.ps1 -IncludeLearnerSetup -ExpectedLabId 66801148 -ReportPath C:\Temp\readiness.txt
    Also verifies the state an attendee's setup leaves behind, for a specific lab instance.
#>
[CmdletBinding()]
param(
    [string]$Distro,
    [string]$StatePath = 'C:\terraform\terraform.tfstate',
    [string]$LabRoot,
    [string]$ExpectedLabId,
    [switch]$IncludeLearnerSetup,
    [switch]$SkipAzure,
    [switch]$SkipKubernetes,
    [int]$AzureTimeoutSeconds = 240,
    [string]$ReportPath,
    [switch]$Json
)

$ErrorActionPreference = 'Continue'
$script:Started = Get-Date
$script:Quiet = [bool]$Json
$script:Results = New-Object System.Collections.Generic.List[object]
$script:Section = ''
$script:Distro = $Distro
$script:WslOk = $false
$script:AzureSkipReason = ''

# ---------------------------------------------------------------------------------------------------------
# What the repository says a ready lab looks like
# ---------------------------------------------------------------------------------------------------------

# infra/main.tf: required_version = ">= 1.10, < 2.0"
$TerraformMin = [version]'1.10.0'
$TerraformMaxExclusive = [version]'2.0.0'
# Module 2 uses `kubectl wait --for=create`, which needs kubectl 1.31 or later.
$KubectlMin = [version]'1.31.0'
# setup/artifact-lock.json backstage.nodeMajor is read from the bundle; this is the fallback.
$NodeMajorDefault = 24
# infra/main.tf azapi_update_resource.add_cluster_features
$AksApiVersion = '2026-08-02-preview'

# setup/bootstrap.sh: every one of these `lab` output fields must be a nonempty string.
$RequiredLabOutputs = @(
    'LAB_ID', 'AZURE_SUBSCRIPTION_ID', 'AZURE_TENANT_ID', 'AZURE_LOCATION', 'AKS_RESOURCE_GROUP',
    'CONTROL_CLUSTER_NAME', 'AKS_CLUSTER_NAME', 'WORKLOAD_CLUSTER_ID', 'WORKLOAD_SERVER', 'WORKLOAD_CA',
    'PROVISIONER_CLIENT_ID', 'ARGO_CLIENT_ID', 'MODEL_RESOURCE_ID', 'MODEL_ENDPOINT', 'MODEL_DEPLOYMENT',
    'WORKLOAD_OIDC_ISSUER', 'LOG_ANALYTICS_WORKSPACE_ID', 'AZURE_MONITOR_WORKSPACE_ID',
    'CLUSTER_OPERATOR_OBJECT_IDS', 'STATE_ACCOUNT', 'STATE_CONTAINER', 'STATE_KEY'
)

# setup/README.md "Organizer preparation" and setup/fast-track.sh check_tools, plus tools the scripts call.
$ToolSpecs = @(
    @{ Name = 'git';       Required = $true;  Note = 'setup scripts, every PR step' },
    @{ Name = 'gh';        Required = $true;  Note = 'GitHub sign-in and PR steps' },
    @{ Name = 'az';        Required = $true;  Note = 'bootstrap.sh and the guide' },
    @{ Name = 'terraform'; Required = $true;  Note = 'make setup reads the bootstrap state' },
    @{ Name = 'kubectl';   Required = $true;  Note = 'every module' },
    @{ Name = 'kubelogin'; Required = $true;  Note = 'kubeconfig sign-in through the Azure CLI' },
    @{ Name = 'node';      Required = $true;  Note = 'Backstage' },
    @{ Name = 'jq';        Required = $true;  Note = 'bootstrap.sh and the guide' },
    @{ Name = 'envsubst';  Required = $true;  Note = 'renders the platform files' },
    @{ Name = 'make';      Required = $true;  Note = 'make setup, make auth, make backstage' },
    @{ Name = 'curl';      Required = $true;  Note = 'apply-tokens.sh checks token permissions' },
    @{ Name = 'base64';    Required = $true;  Note = 'start-argocd.sh prints the admin password' },
    @{ Name = 'code';      Required = $true;  Note = 'the guide runs code "$HOME/prel37/prel37.code-workspace"' },
    @{ Name = 'unzip';     Required = $false; Note = 'only to extract the bundle during image preparation' },
    @{ Name = 'ss';        Required = $false; Note = 'Appendix A uses it to find a stale listener' }
)

# Files `git archive` puts in the bundle that setup, the guide, or the Backstage preparation read.
$RequiredBundleFiles = @(
    '.lab-bundle', 'Makefile',
    'setup/bootstrap.sh', 'setup/fast-track.sh', 'setup/machine-setup.sh', 'setup/bundle-setup.sh',
    'setup/apply-tokens.sh', 'setup/start-backstage.sh', 'setup/start-argocd.sh', 'setup/start-app.sh',
    'setup/artifact-lock.json', 'setup/workload-cluster.yaml',
    'infra/main.tf',
    'src/backstage/App.tsx', 'src/backstage/index.ts', 'src/backstage/app-config.lab.yaml',
    'src/platform/bootstrap/packages.yaml', 'src/platform/bootstrap/provider-config.yaml',
    'src/platform/bootstrap/control.yaml', 'src/platform/bootstrap/roots.yaml',
    'src/platform/bootstrap/environment.yaml', 'src/platform/bootstrap/workload.yaml',
    'src/platform/api/xrd.yaml', 'src/platform/api/composition.yaml',
    'src/platform/catalog/catalog.yaml',
    'src/platform/backstage/templates/ai-app/template.yaml',
    'src/platform/backstage/templates/app-environment/template.yaml',
    'src/platform/charts/fourth-coffee/Chart.yaml', 'src/platform/charts/fourth-coffee/values.schema.json',
    'src/platform/charts/fourth-coffee/templates/application.yaml',
    'src/platform/charts/namespace-baseline/Chart.yaml',
    'src/platform/charts/namespace-baseline/templates/baseline.yaml',
    'src/platform/opentofu/managed-namespace/main.tf',
    'src/platform/opentofu/managed-namespace/.terraform.lock.hcl',
    'src/platform/profiles/workload-small.yaml', 'src/platform/profiles/workload-standard.yaml',
    'src/platform/examples/request.yaml', 'src/platform/docs/recovery.md',
    'src/platform/prel37.code-workspace.template',
    'src/answers/product-brief.md', 'src/evidence/profile-comparison.md',
    'src/queries/application-model-call.kql',
    'src/exercises/application/values.yaml', 'src/exercises/application/profile.yaml'
)

# Hosts WSL must reach (setup/README.md "Organizer preparation"). Any HTTP answer means it is reachable.
$NetworkTargets = @(
    @{ Name = 'Azure sign-in';        Url = 'https://login.microsoftonline.com/' },
    @{ Name = 'Azure Resource Manager'; Url = 'https://management.azure.com/' },
    @{ Name = 'GitHub';               Url = 'https://github.com/' },
    @{ Name = 'GitHub API';           Url = 'https://api.github.com/' },
    @{ Name = 'GitHub Container Registry'; Url = 'https://ghcr.io/v2/' },
    @{ Name = 'Upbound package registry';  Url = 'https://xpkg.upbound.io/' },
    @{ Name = 'Crossplane package registry'; Url = 'https://xpkg.crossplane.io/' }
)

# Namespaces `az provider list` must show as Registered for the foundation and for vending (infra/main.tf).
$RequiredProviders = @(
    'Microsoft.ContainerService', 'Microsoft.Insights', 'Microsoft.OperationalInsights',
    'Microsoft.CognitiveServices', 'Microsoft.ManagedIdentity', 'Microsoft.Monitor',
    'Microsoft.PolicyInsights', 'Microsoft.Authorization', 'Microsoft.Storage'
)

# ---------------------------------------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------------------------------------

function Write-Line {
    param([string]$Text, [string]$Color)
    if ($script:Quiet) { return }
    if ($Color) { Write-Host $Text -ForegroundColor $Color } else { Write-Host $Text }
}

function Start-Section {
    param([string]$Title)
    $script:Section = $Title
    Write-Line ''
    Write-Line ('== ' + $Title + ' ==') 'Cyan'
}

function Add-Result {
    param([string]$Status, [string]$Name, [string]$Detail)
    $script:Results.Add([pscustomobject]@{ Section = $script:Section; Status = $Status; Name = $Name; Detail = $Detail })
    $color = 'Gray'
    if ($Status -eq 'PASS') { $color = 'Green' }
    elseif ($Status -eq 'WARN') { $color = 'Yellow' }
    elseif ($Status -eq 'FAIL') { $color = 'Red' }
    elseif ($Status -eq 'SKIP') { $color = 'DarkGray' }
    $line = '[{0}] {1}' -f $Status, $Name
    if ($Detail) { $line += ' - ' + $Detail }
    Write-Line $line $color
}
function Add-Pass { param([string]$Name, [string]$Detail) Add-Result 'PASS' $Name $Detail }
function Add-Warn { param([string]$Name, [string]$Detail) Add-Result 'WARN' $Name $Detail }
function Add-Fail { param([string]$Name, [string]$Detail) Add-Result 'FAIL' $Name $Detail }
function Add-Info { param([string]$Name, [string]$Detail) Add-Result 'INFO' $Name $Detail }
function Add-Skip { param([string]$Name, [string]$Detail) Add-Result 'SKIP' $Name $Detail }

function Limit-Text {
    param([string]$Text, [int]$Max = 220)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $t = ($Text -replace '\s+', ' ').Trim()
    if ($t.Length -gt $Max) { return $t.Substring(0, $Max) + '...' }
    return $t
}

function Get-Prop {
    # Reads a nested property path without failing on missing members. Path items can be names or array indexes.
    param($Object, [object[]]$Path)
    $cur = $Object
    foreach ($p in $Path) {
        if ($null -eq $cur) { return $null }
        if ($p -is [int]) {
            $arr = @($cur)
            if ($p -ge $arr.Count) { return $null }
            $cur = $arr[$p]
        } elseif ($cur -is [System.Collections.IDictionary]) {
            if ($cur.Contains($p)) { $cur = $cur[$p] } else { return $null }
        } else {
            $prop = $cur.PSObject.Properties[[string]$p]
            if ($null -eq $prop) { return $null }
            $cur = $prop.Value
        }
    }
    return $cur
}

function Get-AksProp {
    # `az rest` returns the ARM shape (values under properties); `az aks show` flattens them. Accept both.
    param($Json, [object[]]$Path)
    $v = Get-Prop $Json (@('properties') + $Path)
    if ($null -eq $v) { $v = Get-Prop $Json $Path }
    return $v
}

function ConvertTo-VersionOrNull {
    param([string]$Text)
    if ($Text -match '(\d+)\.(\d+)(?:\.(\d+))?') {
        $patch = '0'
        if ($Matches[3]) { $patch = $Matches[3] }
        return [version]('{0}.{1}.{2}' -f $Matches[1], $Matches[2], $patch)
    }
    return $null
}

function ConvertFrom-JsonSafe {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try { return ($Text | ConvertFrom-Json) } catch { return $null }
}

# ---------------------------------------------------------------------------------------------------------
# Process helpers
# ---------------------------------------------------------------------------------------------------------

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$File,
        [string]$Arguments = '',
        [string]$InputText,
        [int]$TimeoutSec = 60,
        [hashtable]$Environment
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    if ($Environment) {
        foreach ($k in $Environment.Keys) { $psi.EnvironmentVariables[$k] = [string]$Environment[$k] }
    }
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    try {
        [void]$p.Start()
    } catch {
        return [pscustomobject]@{ Started = $false; TimedOut = $false; ExitCode = -1; Out = ''; Err = $_.Exception.Message }
    }
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $errTask = $p.StandardError.ReadToEndAsync()
    try {
        if ($InputText) {
            $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($InputText)
            $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
            $p.StandardInput.BaseStream.Flush()
        }
        $p.StandardInput.Close()
    } catch { }
    $done = $p.WaitForExit($TimeoutSec * 1000)
    if (-not $done) {
        try { $p.Kill() } catch { }
        [void]$p.WaitForExit(5000)
    }
    $out = ''
    $err = ''
    try { if ($outTask.Wait(10000)) { $out = $outTask.Result } } catch { }
    try { if ($errTask.Wait(10000)) { $err = $errTask.Result } } catch { }
    $code = -1
    if ($done) { $code = $p.ExitCode }
    # wsl.exe prints its own messages as UTF-16; dropping the NUL bytes leaves readable text.
    return [pscustomobject]@{
        Started = $true; TimedOut = (-not $done); ExitCode = $code
        Out = ($out -replace "`0", ''); Err = ($err -replace "`0", '')
    }
}

function Invoke-Wsl {
    # Runs a bash script inside WSL as an interactive login shell, which is what an attendee's Ubuntu terminal
    # is (so nvm-installed Node and PATH changes in ~/.bashrc are found). The script arrives on stdin.
    param([string]$Script, [int]$TimeoutSec = 90)
    $argText = ''
    if ($script:Distro) { $argText += '-d ' + $script:Distro + ' ' }
    $argText += '-e bash -lic "eval \"$(cat)\""'
    $text = ($Script -replace "`r`n", "`n") + "`n"
    return Invoke-Native -File 'wsl.exe' -Arguments $argText -InputText $text -TimeoutSec $TimeoutSec -Environment @{ WSL_UTF8 = '1' }
}

function New-BashEnv {
    param([System.Collections.Specialized.OrderedDictionary]$Vars)
    $sb = New-Object System.Text.StringBuilder
    foreach ($k in $Vars.Keys) {
        $v = [string]$Vars[$k]
        if ($k -notmatch '^[A-Z][A-Z0-9_]*$') { throw "Unsafe variable name: $k" }
        if ($v -match "['\r\n]") { throw "Unsafe value for ${k}: it contains a quote or a line break." }
        [void]$sb.AppendLine("export $k='$v'")
    }
    return $sb.ToString()
}

# Shared bash prelude: `run <key> <command...>` prints one block per command and keeps stderr apart.
$BashPrelude = @'
__e="$(mktemp 2>/dev/null || echo /tmp/prel37-check.$$)"
trap 'rm -f "$__e" "$KC"' EXIT
T() { timeout "${CMD_TIMEOUT:-90}" "$@"; }
run() {
  local key="$1"; shift
  local out rc
  out="$("$@" 2>"$__e")"; rc=$?
  printf '@@BEGIN %s\n%s\n@@RC %s\n@@ERR %s\n@@END %s\n' "$key" "$out" "$rc" "$(head -c 500 "$__e" | tr '\r\n' '  ')" "$key"
  return "$rc"
}
'@

function ConvertFrom-WslBlocks {
    param([string]$Text)
    $map = @{}
    $t = $Text -replace "`r", ''
    $rx = New-Object System.Text.RegularExpressions.Regex('(?s)@@BEGIN (\S+)\n(.*?)\n?@@RC (-?\d+)\n@@ERR (.*?)\n@@END \1')
    foreach ($m in $rx.Matches($t)) {
        $map[$m.Groups[1].Value] = [pscustomobject]@{
            Out = $m.Groups[2].Value.TrimEnd("`n")
            Rc  = [int]$m.Groups[3].Value
            Err = $m.Groups[4].Value.Trim()
        }
    }
    return $map
}

function Invoke-WslBatch {
    # Sends the prelude plus a script and returns the parsed blocks, or $null with the reason in $script:BatchError.
    param([string]$Script, [int]$TimeoutSec = 90)
    $script:BatchError = ''
    $r = Invoke-Wsl -Script ($BashPrelude + "`n" + $Script) -TimeoutSec $TimeoutSec
    if (-not $r.Started) { $script:BatchError = 'wsl.exe could not start: ' + $r.Err; return $null }
    if ($r.TimedOut) { $script:BatchError = "The WSL commands did not finish within $TimeoutSec seconds."; return $null }
    $blocks = ConvertFrom-WslBlocks -Text $r.Out
    if ($blocks.Count -eq 0) {
        $script:BatchError = 'WSL returned no results. ' + (Limit-Text ($r.Out + ' ' + $r.Err) 260)
        return $null
    }
    return $blocks
}

function Get-Block {
    param($Blocks, [string]$Key)
    if ($null -eq $Blocks) { return $null }
    if ($Blocks.ContainsKey($Key)) { return $Blocks[$Key] }
    return $null
}

function Get-BlockOut {
    # The block's stdout when the command succeeded, otherwise $null.
    param($Blocks, [string]$Key)
    $b = Get-Block $Blocks $Key
    if ($null -eq $b -or $b.Rc -ne 0) { return $null }
    return $b.Out
}

function Test-TcpPort {
    param([string]$HostName, [int]$Port, [int]$TimeoutMs = 2000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $client.EndConnect($iar)
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

function Convert-ToWslPath {
    param([string]$WindowsPath)
    if ($WindowsPath -match '^([A-Za-z]):[\\/](.*)$') {
        return '/mnt/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
    }
    return $WindowsPath
}

# ---------------------------------------------------------------------------------------------------------
# 1. Windows host
# ---------------------------------------------------------------------------------------------------------

Write-Line ''
Write-Line 'PREL37 lab readiness check' 'White'
Write-Line ('Started {0} on {1}, PowerShell {2}' -f $script:Started.ToString('yyyy-MM-dd HH:mm:ss'), $env:COMPUTERNAME, $PSVersionTable.PSVersion) 'Gray'

Start-Section '1. Windows host'

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    Add-Info 'Operating system' ('{0}, build {1}, last boot {2}' -f $os.Caption, $os.BuildNumber, $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm'))
    if ($os.Caption -notmatch 'Windows 11') { Add-Warn 'Windows version' 'The lab image is expected to be Windows 11.' }
} catch {
    Add-Warn 'Operating system' ('Could not read it: ' + (Limit-Text $_.Exception.Message))
}

$wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wslCmd) {
    Add-Fail 'WSL' 'wsl.exe is not installed. Install WSL 2 and an Ubuntu distribution.'
} else {
    $list = Invoke-Native -File 'wsl.exe' -Arguments '-l -v' -TimeoutSec 30 -Environment @{ WSL_UTF8 = '1' }
    $distros = @()
    foreach ($line in ($list.Out -split "`r?`n")) {
        if ($line -match '^\s*(\*?)\s*([A-Za-z0-9._-]+)\s+(Running|Stopped|Installing|Uninstalling|Converting)\s+(\d)\s*$') {
            $distros += [pscustomobject]@{ Default = ($Matches[1] -eq '*'); Name = $Matches[2]; State = $Matches[3]; Version = [int]$Matches[4] }
        }
    }
    if ($distros.Count -eq 0) {
        Add-Fail 'WSL distributions' ('None found. ' + (Limit-Text ($list.Out + ' ' + $list.Err) 200))
    } else {
        $chosen = $null
        if ($script:Distro) {
            $chosen = $distros | Where-Object { $_.Name -eq $script:Distro } | Select-Object -First 1
            if (-not $chosen) { Add-Fail 'WSL distribution' ("'{0}' is not installed. Installed: {1}" -f $script:Distro, (($distros | ForEach-Object { $_.Name }) -join ', ')) }
        } else {
            $chosen = $distros | Where-Object { $_.Name -like 'Ubuntu*' } | Select-Object -First 1
            if (-not $chosen) { $chosen = $distros | Where-Object { $_.Default -and $_.Name -notlike 'docker-desktop*' } | Select-Object -First 1 }
            if (-not $chosen) { $chosen = $distros | Where-Object { $_.Name -notlike 'docker-desktop*' } | Select-Object -First 1 }
            if (-not $chosen) { Add-Fail 'WSL distribution' 'No Linux distribution other than docker-desktop. Install Ubuntu.' }
        }
        if ($chosen) {
            $script:Distro = $chosen.Name
            if ($script:Distro -notmatch '^[A-Za-z0-9._-]+$') {
                Add-Fail 'WSL distribution' 'The name has characters this script cannot pass safely. Use -Distro with a simple name.'
            } else {
                $script:WslOk = $true
                if ($chosen.Name -notlike 'Ubuntu*') { Add-Warn 'WSL distribution' ("'{0}' is not Ubuntu. The guide says to open the Ubuntu profile." -f $chosen.Name) }
                if ($chosen.Version -ne 2) { Add-Warn 'WSL version' ("'{0}' runs WSL {1}. Use WSL 2." -f $chosen.Name, $chosen.Version) }
                else { Add-Pass 'WSL distribution' ("'{0}', WSL 2, {1}" -f $chosen.Name, $chosen.State) }
            }
        }
    }
}

# VS Code and its WSL extension
$codeCmd = $null
$candidates = @()
$found = Get-Command code.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) { $candidates += $found.Source }
if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd') }
if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd') }
foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { $codeCmd = $c; break } }
if (-not $codeCmd) {
    Add-Fail 'VS Code' 'Not found on Windows. The guide opens the workspace with code from WSL.'
} else {
    $ext = Invoke-Native -File 'cmd.exe' -Arguments ('/d /s /c ""' + $codeCmd + '" --list-extensions"') -TimeoutSec 60
    if ($ext.TimedOut -or -not $ext.Started) {
        Add-Warn 'VS Code' 'Installed, but listing its extensions did not finish.'
    } elseif ($ext.Out -match '(?im)^ms-vscode-remote\.remote-wsl\s*$') {
        Add-Pass 'VS Code' 'Installed, with the WSL extension (ms-vscode-remote.remote-wsl).'
    } else {
        Add-Fail 'VS Code WSL extension' 'ms-vscode-remote.remote-wsl is not installed. Without it, VS Code cannot open ~/prel37 from WSL.'
    }
}

$edge = $null
foreach ($c in @((Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'), (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'))) {
    if ($c -and (Test-Path -LiteralPath $c)) { $edge = $c; break }
}
if ($edge) { Add-Pass 'Microsoft Edge' 'Installed.' } else { Add-Warn 'Microsoft Edge' 'Not found at the usual paths. The guide signs in and opens the lab apps in Edge.' }

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $wt -and $env:LOCALAPPDATA) {
    if (Test-Path -LiteralPath (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe')) { $wt = 'present' }
}
if ($wt) { Add-Pass 'Windows Terminal' 'Installed.' } else { Add-Warn 'Windows Terminal' 'Not found. The guide opens the Ubuntu profile in Windows Terminal, or says to run wsl from PowerShell.' }

# ---------------------------------------------------------------------------------------------------------
# 2. Foundation state
# ---------------------------------------------------------------------------------------------------------

Start-Section '2. Foundation state (bootstrap Terraform state)'

$stateSummary = $null
$tfDir = Split-Path -Parent $StatePath

if (Test-Path -LiteralPath $tfDir) {
    $lock = Join-Path $tfDir '.terraform.tfstate.lock.info'
    if (Test-Path -LiteralPath $lock) {
        Add-Fail 'Terraform lock' "$lock exists. The life cycle action's apply is still running, or it was stopped before it finished (for example by the 60-minute action limit)."
    } else {
        Add-Pass 'Terraform lock' 'No lock file, so no apply is holding the state.'
    }
    $tfProcs = @(Get-Process -Name terraform -ErrorAction SilentlyContinue)
    if ($tfProcs.Count -gt 0) {
        Add-Warn 'Terraform process' ('{0} terraform process(es) are running on Windows. Provisioning may still be in progress.' -f $tfProcs.Count)
    }
} else {
    Add-Fail 'Terraform directory' "$tfDir does not exist. The life cycle action that provisions the foundation has not run."
}

if (-not (Test-Path -LiteralPath $StatePath)) {
    Add-Fail 'Bootstrap state' "$StatePath does not exist. make setup would only prepare the VM and stop. Complete provisioning first."
} else {
    $fi = Get-Item -LiteralPath $StatePath
    if ($fi.Length -eq 0) {
        Add-Fail 'Bootstrap state' "$StatePath is empty."
    } else {
        $age = (Get-Date) - $fi.LastWriteTime
        Add-Info 'Bootstrap state file' ('{0:N0} KB, last written {1} ({2:N1} hours ago)' -f ($fi.Length / 1KB), $fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm'), $age.TotalHours)
        try {
            $raw = [System.IO.File]::ReadAllText($StatePath)
            $state = $raw | ConvertFrom-Json
            $res = New-Object System.Collections.Generic.List[object]
            foreach ($r in @($state.resources)) {
                if ($r.mode -ne 'managed') { continue }
                $inst = @($r.instances)
                $tainted = @($inst | Where-Object { $_.PSObject.Properties['status'] -and $_.status -eq 'tainted' } | ForEach-Object { [string]$_.index_key })
                $res.Add([pscustomobject]@{ Address = ('{0}.{1}' -f $r.type, $r.name); Count = $inst.Count; Tainted = $tainted })
            }
            $labOut = $null
            if ($state.outputs -and $state.outputs.PSObject.Properties['lab']) { $labOut = $state.outputs.lab.value }
            $ctlHost = $null
            foreach ($r in @($state.resources)) {
                if ($r.mode -eq 'managed' -and $r.type -eq 'azurerm_kubernetes_cluster' -and $r.name -eq 'control') {
                    $kc = Get-Prop $r @('instances', 0, 'attributes', 'kube_config', 0, 'host')
                    if ($kc) { $ctlHost = [string]$kc }
                }
            }
            $stateSummary = [pscustomobject]@{ Version = $state.version; TerraformVersion = [string]$state.terraform_version; Lab = $labOut; Resources = $res; ControlHost = $ctlHost }
            $raw = $null; $state = $null
        } catch {
            $parseError = $_.Exception.Message
            if ($script:WslOk) {
                # A key that differs only by case breaks ConvertFrom-Json in Windows PowerShell. Let jq read it instead.
                $wslState = Convert-ToWslPath $StatePath
                if ($wslState -notmatch "^[A-Za-z0-9._/ -]+$") { $wslState = '' }
                if ($wslState) {
                    $jqScript = @'
run state sh -c 'jq -c "{version, terraform_version, lab: .outputs.lab.value, controlHost: ([.resources[] | select(.mode==\"managed\" and .type==\"azurerm_kubernetes_cluster\" and .name==\"control\") | .instances[0].attributes.kube_config[0].host] | first), resources: [.resources[] | select(.mode==\"managed\") | {address: (.type + \".\" + .name), count: (.instances | length), tainted: [.instances[] | select(.status==\"tainted\") | (.index_key // \"\")]}]}" "$1"' _ "$STATE_WSL"
'@
                    $envText = New-BashEnv ([ordered]@{ STATE_WSL = $wslState })
                    $b = Invoke-WslBatch -Script ($envText + $jqScript) -TimeoutSec 60
                    $js = ConvertFrom-JsonSafe (Get-BlockOut $b 'state')
                    if ($js) {
                        $res = New-Object System.Collections.Generic.List[object]
                        foreach ($r in @($js.resources)) { $res.Add([pscustomobject]@{ Address = [string]$r.address; Count = [int]$r.count; Tainted = @($r.tainted | Where-Object { $_ -ne '' }) }) }
                        $stateSummary = [pscustomobject]@{ Version = $js.version; TerraformVersion = [string]$js.terraform_version; Lab = $js.lab; Resources = $res; ControlHost = [string]$js.controlHost }
                        Add-Info 'Bootstrap state parser' 'Read with jq in WSL because PowerShell could not parse the file.'
                    }
                }
            }
            if (-not $stateSummary) { Add-Fail 'Bootstrap state' ('The file could not be parsed: ' + (Limit-Text $parseError)) }
        }
    }
}

$LabOut = $null
$OperatorIds = @()
if ($stateSummary) {
    $s = $stateSummary
    if ($s.Version -eq 4) { Add-Pass 'State format' 'Version 4.' } else { Add-Warn 'State format' ("Version '{0}'; this script expects 4." -f $s.Version) }

    $tfv = ConvertTo-VersionOrNull $s.TerraformVersion
    if ($tfv) {
        if ($tfv -ge $TerraformMin -and $tfv -lt $TerraformMaxExclusive) { Add-Pass 'Terraform that wrote the state' ('{0} (infra/main.tf needs >= 1.10, < 2.0)' -f $s.TerraformVersion) }
        else { Add-Warn 'Terraform that wrote the state' ('{0} is outside infra/main.tf required_version (>= 1.10, < 2.0).' -f $s.TerraformVersion) }
    }

    $LabOut = $s.Lab
    if ($null -eq $LabOut) {
        Add-Fail 'lab output' 'The state has no `lab` output. Terraform writes it only when an apply finishes, so provisioning did not complete. make setup cannot read the foundation.'
    } else {
        $missing = @()
        foreach ($name in $RequiredLabOutputs) {
            $v = Get-Prop $LabOut @($name)
            if (-not ($v -is [string]) -or [string]::IsNullOrEmpty($v)) { $missing += $name }
        }
        if ($missing.Count -gt 0) { Add-Fail 'lab output fields' ('Missing or empty: ' + ($missing -join ', ') + '. bootstrap.sh stops on any of these.') }
        else { Add-Pass 'lab output fields' ('All {0} fields bootstrap.sh needs are present and nonempty.' -f $RequiredLabOutputs.Count) }

        $labId = [string](Get-Prop $LabOut @('LAB_ID'))
        if ($labId -notmatch '^[a-z0-9]{4,12}$') { Add-Fail 'LAB_ID' ("'{0}' is not 4-12 lowercase letters or digits." -f $labId) }
        else { Add-Pass 'LAB_ID' $labId }
        if ($ExpectedLabId) {
            if ($labId -eq $ExpectedLabId) { Add-Pass 'LAB_ID matches -ExpectedLabId' $ExpectedLabId }
            else { Add-Fail 'LAB_ID matches -ExpectedLabId' ("State has '{0}', expected '{1}'. The repository names prel37-<lab ID>-* would not match this lab instance." -f $labId, $ExpectedLabId) }
        }

        # Names infra/main.tf derives from the lab ID. A mismatch means the state is from another lab or an edited root.
        $rg = [string](Get-Prop $LabOut @('AKS_RESOURCE_GROUP'))
        $nameChecks = @(
            @{ Field = 'CONTROL_CLUSTER_NAME'; Expect = "aks-prel37-$labId-control"; Mode = 'equals' },
            @{ Field = 'AKS_CLUSTER_NAME'; Expect = "aks-prel37-$labId-workload"; Mode = 'equals' },
            @{ Field = 'MODEL_DEPLOYMENT'; Expect = 'lab-model'; Mode = 'equals' },
            @{ Field = 'STATE_CONTAINER'; Expect = 'namespace-state'; Mode = 'equals' },
            @{ Field = 'STATE_KEY'; Expect = "$labId/environment.tfstate"; Mode = 'equals' },
            @{ Field = 'STATE_ACCOUNT'; Expect = "stp37$labId"; Mode = 'prefix' },
            @{ Field = 'MODEL_RESOURCE_ID'; Expect = "/aoai-prel37-$labId"; Mode = 'suffix' },
            @{ Field = 'LOG_ANALYTICS_WORKSPACE_ID'; Expect = "/law-prel37-$labId"; Mode = 'suffix' },
            @{ Field = 'AZURE_MONITOR_WORKSPACE_ID'; Expect = "/amw-prel37-$labId"; Mode = 'suffix' },
            @{ Field = 'MODEL_ENDPOINT'; Expect = "https://aoai-prel37-$labId.openai.azure.com/openai/v1/"; Mode = 'equals' }
        )
        $nameProblems = @()
        foreach ($c in $nameChecks) {
            $v = [string](Get-Prop $LabOut @($c.Field))
            $ok = $false
            if ($c.Mode -eq 'equals') { $ok = ($v -eq $c.Expect) }
            elseif ($c.Mode -eq 'prefix') { $ok = $v.StartsWith($c.Expect) }
            else { $ok = $v.EndsWith($c.Expect) }
            if (-not $ok) { $nameProblems += ('{0}={1} (expected {2} {3})' -f $c.Field, (Limit-Text $v 80), $c.Mode, $c.Expect) }
        }
        if ($nameProblems.Count -gt 0) { Add-Warn 'Resource names' ('Do not follow infra/main.tf for this lab ID: ' + ($nameProblems -join '; ')) }
        else { Add-Pass 'Resource names' 'Match what infra/main.tf derives from the lab ID.' }
        foreach ($f in @('AZURE_SUBSCRIPTION_ID', 'AZURE_TENANT_ID')) {
            $v = [string](Get-Prop $LabOut @($f))
            if ($v -notmatch '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') { Add-Fail $f ("'{0}' is not a GUID." -f (Limit-Text $v 60)) }
        }
        $OperatorIds = @(([string](Get-Prop $LabOut @('CLUSTER_OPERATOR_OBJECT_IDS'))) -split ',' | Where-Object { $_ })
        Add-Info 'Resource group and region' ('{0} in {1}' -f $rg, (Get-Prop $LabOut @('AZURE_LOCATION')))
    }

    # Every resource infra/main.tf creates. n is the number of cluster operators (the learner, plus the bootstrap
    # identity when it is not the learner).
    $n = [Math]::Max(1, $OperatorIds.Count)
    $expected = [ordered]@{
        'azurerm_kubernetes_cluster.control'                    = 1
        'azurerm_kubernetes_automatic_cluster.workload'         = 1
        'helm_release.crossplane'                               = 1
        'azapi_update_resource.add_cluster_features'            = 1
        'azurerm_log_analytics_workspace.lab'                   = 1
        'azurerm_monitor_workspace.lab'                         = 1
        'azurerm_storage_account.state'                         = 1
        'azapi_resource.state_container'                        = 1
        'azurerm_cognitive_account.model'                       = 1
        'azurerm_cognitive_deployment.model'                    = 1
        'azurerm_user_assigned_identity.lab'                    = 2
        'azurerm_federated_identity_credential.lab'             = 3
        'azurerm_role_assignment.operator_cluster_access'       = 2 * $n
        'azurerm_role_assignment.operator_cluster_credentials'  = 2 * $n
        'azurerm_role_assignment.provisioner_namespace'         = 1
        'azurerm_role_assignment.provisioner_read'              = 1
        'azurerm_role_assignment.provisioner_app_resources'     = 2
        'azurerm_role_definition.provisioner_otlp'              = 1
        'azurerm_role_assignment.provisioner_otlp'              = 1
        'azurerm_role_assignment.provisioner_otlp_grants'       = 1
        'azurerm_role_assignment.provisioner_model_grants'      = 1
        'azurerm_role_assignment.provisioner_namespace_grants'  = 1
        'azurerm_role_assignment.provisioner_monitoring_grants' = 1
        'azurerm_role_assignment.provisioner_state'             = 1
        'azurerm_role_assignment.argocd_workload'               = 1
        'azurerm_kubernetes_cluster_extension.argocd'           = 1
    }
    $have = @{}
    foreach ($r in $s.Resources) { $have[$r.Address] = $r }
    $absent = @()
    $short = @()
    foreach ($addr in $expected.Keys) {
        if (-not $have.ContainsKey($addr)) { $absent += $addr }
        elseif ($have[$addr].Count -lt $expected[$addr]) { $short += ('{0} has {1} of {2}' -f $addr, $have[$addr].Count, $expected[$addr]) }
    }
    if ($absent.Count -gt 0) { Add-Fail 'Foundation resources' ('{0} of {1} resources infra/main.tf creates are not in the state: {2}' -f $absent.Count, $expected.Count, ($absent -join ', ')) }
    if ($short.Count -gt 0) { Add-Fail 'Foundation resource instances' ($short -join '; ') }
    if ($absent.Count -eq 0 -and $short.Count -eq 0) { Add-Pass 'Foundation resources' ('All {0} resources infra/main.tf creates are in the state.' -f $expected.Count) }
    $taintedAll = @()
    foreach ($r in $s.Resources) {
        if (@($r.Tainted).Count -gt 0) {
            $keys = @($r.Tainted | Where-Object { $_ })
            if ($keys.Count -gt 0) { $taintedAll += ('{0}[{1}]' -f $r.Address, ($keys -join ',')) } else { $taintedAll += $r.Address }
        }
    }
    if ($taintedAll.Count -gt 0) { Add-Fail 'Half-created resources' ('Tainted in the state (a create failed or was interrupted): ' + ($taintedAll -join ', ')) }
    else { Add-Pass 'Half-created resources' 'None are tainted.' }
}

# The Terraform root that produced the state, if it is still on this VM.
$tfMain = Join-Path $tfDir 'main.tf'
$tfLockHcl = Join-Path $tfDir '.terraform.lock.hcl'
$script:WindowsMainTfSha = $null
if (Test-Path -LiteralPath $tfMain) {
    try { $script:WindowsMainTfSha = (Get-FileHash -LiteralPath $tfMain -Algorithm SHA256).Hash.ToLower() } catch { }
}
if (Test-Path -LiteralPath $tfLockHcl) {
    $lockText = Get-Content -LiteralPath $tfLockHcl -Raw
    $pins = [ordered]@{ 'registry.terraform.io/hashicorp/azurerm' = '5.9.0'; 'registry.terraform.io/azure/azapi' = '2.13.0'; 'registry.terraform.io/hashicorp/azuread' = '3.10.0' }
    $pinProblems = @()
    foreach ($p in $pins.Keys) {
        $m = [regex]::Match($lockText, '(?s)provider "' + [regex]::Escape($p) + '"\s*\{\s*version\s*=\s*"([^"]+)"')
        if ($m.Success -and $m.Groups[1].Value -ne $pins[$p]) { $pinProblems += ('{0} is {1}, infra/main.tf pins {2}' -f $p, $m.Groups[1].Value, $pins[$p]) }
    }
    if ($pinProblems.Count -gt 0) { Add-Warn 'Provider versions in C:\terraform' ($pinProblems -join '; ') }
    else { Add-Pass 'Provider versions in C:\terraform' 'Match the pins in infra/main.tf.' }
}

# ---------------------------------------------------------------------------------------------------------
# 3. WSL tools
# ---------------------------------------------------------------------------------------------------------

Start-Section '3. WSL tools and the snags the lab test found'

$toolBlocks = $null
$LockFacts = $null
$UserHome = ''
$WslVarOverride = ''
if (-not $script:WslOk) {
    Add-Skip 'WSL checks' 'No usable WSL distribution (see section 1).'
} else {
    $envLines = [ordered]@{ REQ = ($RequiredBundleFiles -join ' ') }
    if ($LabRoot) { $envLines['LAB_ROOT_OVERRIDE'] = $LabRoot }
    $toolScript = New-BashEnv $envLines
    $toolScript += @'
LAB_ROOT="${LAB_ROOT_OVERRIDE:-$HOME/prel37}"
SRC="$LAB_ROOT/setup"
RT="$LAB_ROOT/runtime/backstage"
run user whoami
run home sh -c 'printf "%s" "$HOME"'
run labroot sh -c 'printf "%s" "$1"' _ "$LAB_ROOT"
run os sh -c '. /etc/os-release && printf "%s" "$PRETTY_NAME"'
run kernel uname -r
for t in git gh az terraform kubectl kubelogin node jq envsubst make curl unzip base64 ss code wslview; do
  run "which_$t" sh -c 'command -v "$1" || true' _ "$t"
done
run v_git git --version
run v_gh sh -c 'gh --version | head -n 1'
run v_az az version -o json
run v_terraform terraform version -json
run v_kubectl kubectl version --client -o json
run v_kubelogin sh -c 'kubelogin --version 2>&1 | head -n 3 | tr "\n" " "'
run v_node node --version
run v_jq jq --version
run v_make sh -c 'make --version | head -n 1'
run git_pager sh -c 'printf "%s" "$(git config --global --get core.pager)"'
run env_pager sh -c 'printf "GIT_PAGER=%s PAGER=%s" "$GIT_PAGER" "$PAGER"'
run env_browser sh -c 'printf "%s" "$BROWSER"'
run vscode_server sh -c 'if [ -d "$HOME/.vscode-server" ]; then echo present; else echo absent; fi'
run az_namespace sh -c 'az aks namespace -h >/dev/null 2>&1 && echo yes || echo no'
run bundle_marker sh -c 'head -n 1 "$1/.lab-bundle" 2>/dev/null' _ "$SRC"
run bundle_missing sh -c 'cd "$1" 2>/dev/null || { echo NO_BUNDLE_DIR; exit 0; }; for f in $REQ; do [ -e "$f" ] || echo "$f"; done' _ "$SRC"
run crlf sh -c 'cd "$1" 2>/dev/null && grep -lI "$(printf "\r")" Makefile setup/*.sh 2>/dev/null; true' _ "$SRC"
run lock sh -c 'jq -r "[.backstage.nodeMajor, .backstage.yarn, .backstage.sourceRevision, .application.imageTag, (.application.nativeOtlpWorkloadIdentity|tostring), .rehearsal.status] | @tsv" "$1/setup/artifact-lock.json"' _ "$SRC"
run maintf_sha sh -c 'sha256sum "$1/infra/main.tf" | cut -d" " -f1' _ "$SRC"
run bs_exists sh -c 'if [ -d "$1" ]; then echo yes; else echo no; fi' _ "$RT"
run bs_rev git -C "$RT" rev-parse HEAD
run bs_modules sh -c 'if [ -f "$1/node_modules/.yarn-state.yml" ]; then echo yes; else echo no; fi' _ "$RT"
run bs_yarn sh -c 'ls "$1/.yarn/releases" 2>/dev/null | tr "\n" " "' _ "$RT"
run bs_override sh -c 'if cmp -s "$2/src/backstage/App.tsx" "$1/packages/app/src/App.tsx" && cmp -s "$2/src/backstage/index.ts" "$1/packages/backend/src/index.ts"; then echo same; else echo different; fi' _ "$RT" "$SRC"
run learner_flags sh -c 'cd "$1" 2>/dev/null || exit 0; for f in config/lab.json config/lab.env config/setup.env config/environment.yaml config/artifact-lock.json .state/kubeconfig prel37.code-workspace answers/product-brief.md exercises/application/values.yaml exercises/application/profile.yaml queries/application-model-call.kql evidence/profile-comparison.md platform/.git app-deploy/.git runtime/backstage/app-config.local.yaml .credentials/read-token .credentials/backstage-token; do if [ -s "$f" ]; then echo "$f=yes"; elif [ -e "$f" ]; then echo "$f=empty"; else echo "$f=no"; fi; done' _ "$LAB_ROOT"
'@
    Write-Line 'Reading the WSL environment (this takes a few seconds)...' 'DarkGray'
    $toolBlocks = Invoke-WslBatch -Script $toolScript -TimeoutSec 240
    if ($null -eq $toolBlocks) {
        Add-Fail 'WSL commands' $script:BatchError
        $script:WslOk = $false
    } else {
        $whoami = Get-BlockOut $toolBlocks 'user'
        $UserHome = Get-BlockOut $toolBlocks 'home'
        Add-Info 'WSL user' ('{0}, home {1}, {2}, kernel {3}' -f $whoami, $UserHome, (Get-BlockOut $toolBlocks 'os'), (Get-BlockOut $toolBlocks 'kernel'))
        if ($whoami -eq 'root') { Add-Warn 'WSL user' 'The default user is root. The lab expects a regular user such as labuser.' }

        $nodeMajorWanted = $NodeMajorDefault
        $lockOut = Get-BlockOut $toolBlocks 'lock'
        if ($lockOut) {
            $f = $lockOut -split "`t"
            if ($f.Count -ge 6) {
                $LockFacts = [pscustomobject]@{ NodeMajor = $f[0]; Yarn = $f[1]; BackstageRev = $f[2]; ImageTag = $f[3]; NativeOtlp = $f[4]; Rehearsal = $f[5] }
                if ($f[0] -match '^\d+$') { $nodeMajorWanted = [int]$f[0] }
            }
        }

        foreach ($spec in $ToolSpecs) {
            $name = $spec.Name
            $path = Get-BlockOut $toolBlocks ('which_' + $name)
            if ([string]::IsNullOrWhiteSpace($path)) {
                if ($spec.Required) { Add-Fail "Tool: $name" ("Not found in WSL. Needed for: {0}. Windows executables alone do not satisfy this." -f $spec.Note) }
                else { Add-Warn "Tool: $name" ('Not found in WSL. {0}.' -f $spec.Note) }
                continue
            }
            $detail = $path
            $status = 'PASS'
            switch ($name) {
                'git'       { $detail += ', ' + (Get-BlockOut $toolBlocks 'v_git') }
                'gh'        { $detail += ', ' + (Get-BlockOut $toolBlocks 'v_gh') }
                'jq'        { $detail += ', ' + (Get-BlockOut $toolBlocks 'v_jq') }
                'make'      { $detail += ', ' + (Get-BlockOut $toolBlocks 'v_make') }
                'kubelogin' { $detail += ', ' + (Limit-Text (Get-BlockOut $toolBlocks 'v_kubelogin') 80) }
                'az' {
                    $azj = ConvertFrom-JsonSafe (Get-BlockOut $toolBlocks 'v_az')
                    if ($azj) { $detail += ', azure-cli ' + [string](Get-Prop $azj @('azure-cli')) }
                }
                'terraform' {
                    $tj = ConvertFrom-JsonSafe (Get-BlockOut $toolBlocks 'v_terraform')
                    $tv = ConvertTo-VersionOrNull ([string](Get-Prop $tj @('terraform_version')))
                    if ($tv) {
                        $detail += ', ' + $tv
                        if ($tv -lt $TerraformMin -or $tv -ge $TerraformMaxExclusive) { $status = 'FAIL'; $detail += ' (needs >= 1.10 and < 2.0)' }
                        elseif ($stateSummary) {
                            $sv = ConvertTo-VersionOrNull $stateSummary.TerraformVersion
                            if ($sv -and $sv -gt $tv) { $status = 'FAIL'; $detail += (' is older than {0}, which wrote the state. terraform output would refuse to read it.' -f $sv) }
                        }
                    } else { $status = 'WARN'; $detail += ', version unreadable' }
                }
                'kubectl' {
                    $kj = ConvertFrom-JsonSafe (Get-BlockOut $toolBlocks 'v_kubectl')
                    $kv = ConvertTo-VersionOrNull ([string](Get-Prop $kj @('clientVersion', 'gitVersion')))
                    if ($kv) {
                        $detail += ', ' + $kv
                        if ($kv -lt $KubectlMin) { $status = 'FAIL'; $detail += ' (Module 2 uses kubectl wait --for=create, which needs 1.31 or later)' }
                    }
                }
                'node' {
                    $nv = Get-BlockOut $toolBlocks 'v_node'
                    $detail += ', ' + $nv
                    if ($nv -match '^v(\d+)\.') {
                        if ([int]$Matches[1] -ne $nodeMajorWanted) { $status = 'FAIL'; $detail += (' (Backstage is pinned to Node {0}.x in setup/artifact-lock.json)' -f $nodeMajorWanted) }
                    }
                }
            }
            Add-Result $status "Tool: $name" $detail
        }

        # Snags from the lab test (opuslabtest.md). They do not block setup, but attendees notice them.
        $azj = ConvertFrom-JsonSafe (Get-BlockOut $toolBlocks 'v_az')
        $extNames = @()
        $ext = Get-Prop $azj @('extensions')
        if ($ext) { $extNames = @($ext.PSObject.Properties | ForEach-Object { $_.Name }) }
        if ($extNames -contains 'log-analytics') { Add-Pass 'az extension: log-analytics' 'Installed, so the Module 3 query does not stop to ask.' }
        else { Add-Warn 'az extension: log-analytics' 'Not installed. The Module 3 telemetry query stops to ask whether to install it. Run: az extension add --name log-analytics'  }
        $azNs = Get-BlockOut $toolBlocks 'az_namespace'
        if ($azNs -eq 'yes') { Add-Pass 'az aks namespace' 'The installed az supports it (Module 2 step 8).' }
        elseif ($null -ne $azNs) { Add-Fail 'az aks namespace' 'The installed az does not support `az aks namespace`. Module 2 step 8 uses it. Update the Azure CLI.' }
        $pager = Get-BlockOut $toolBlocks 'git_pager'
        $pagerEnv = Get-BlockOut $toolBlocks 'env_pager'
        if ($pager -eq 'cat' -or $pagerEnv -match 'GIT_PAGER=cat') { Add-Pass 'Git pager' 'Git does not open a pager, so a typed block cannot be swallowed by less.' }
        else { Add-Warn 'Git pager' 'Git opens less for long output, which swallows the rest of a typed block. Run: git config --global core.pager cat  (the guide also uses git --no-pager).' }
        $wslview = Get-BlockOut $toolBlocks 'which_wslview'
        $browser = Get-BlockOut $toolBlocks 'env_browser'
        if (-not [string]::IsNullOrWhiteSpace($wslview) -or -not [string]::IsNullOrWhiteSpace($browser)) { Add-Pass 'Browser for gh auth login' ('wslview or BROWSER is set up ({0}).' -f $(if ($wslview) { $wslview } else { 'BROWSER=' + $browser })) }
        else { Add-Warn 'Browser for gh auth login' 'No wslview and BROWSER is unset, so gh cannot open Edge from WSL and waits silently. Install wslu, or set BROWSER to the Edge path in ~/.profile.' }
        if ((Get-BlockOut $toolBlocks 'vscode_server') -eq 'present') { Add-Pass 'VS Code Server in WSL' '~/.vscode-server is present, so the first code launch does not download it.' }
        else { Add-Info 'VS Code Server in WSL' 'Not downloaded yet. The first `code` launch from WSL downloads it, which needs internet and adds a wait.' }
    }
}

# ---------------------------------------------------------------------------------------------------------
# 4. Lab bundle and Backstage runtime
# ---------------------------------------------------------------------------------------------------------

Start-Section '4. Lab bundle and Backstage runtime'

if (-not $script:WslOk -or $null -eq $toolBlocks) {
    Add-Skip 'Bundle checks' 'WSL results are not available.'
} else {
    $labRootShown = Get-BlockOut $toolBlocks 'labroot'
    $marker = Get-BlockOut $toolBlocks 'bundle_marker'
    $missingFiles = Get-BlockOut $toolBlocks 'bundle_missing'
    if ($missingFiles -match 'NO_BUNDLE_DIR') {
        Add-Fail 'Lab bundle' ("{0}/setup does not exist. Extract prel37-lab-bundle.zip under {0} (setup/README.md 'Build and pre-stage the lab bundle')." -f $labRootShown)
    } else {
        if ([string]::IsNullOrWhiteSpace($marker)) { Add-Fail 'Bundle marker' '.lab-bundle is missing, so make setup would take the Azure-provisioning path. Keep the marker from the bundle.' }
        else { Add-Pass 'Bundle marker' ('.lab-bundle records source commit ' + (Limit-Text $marker 12)) }
        $miss = @($missingFiles -split "`n" | Where-Object { $_ -and $_ -ne '.lab-bundle' })
        if ($miss.Count -gt 0) { Add-Fail 'Bundle files' ('{0} of {1} expected files are missing: {2}' -f $miss.Count, $RequiredBundleFiles.Count, ($miss -join ', ')) }
        else { Add-Pass 'Bundle files' ('All {0} files setup and the guide read are present.' -f $RequiredBundleFiles.Count) }
        $crlf = Get-BlockOut $toolBlocks 'crlf'
        if (-not [string]::IsNullOrWhiteSpace($crlf)) { Add-Fail 'Script line endings' ('CRLF line endings break bash in: ' + (($crlf -split "`n") -join ', ') + '. Keep shell scripts in LF.') }
        else { Add-Pass 'Script line endings' 'The Makefile and setup/*.sh use LF.' }
        $linuxSha = Get-BlockOut $toolBlocks 'maintf_sha'
        if ($script:WindowsMainTfSha -and $linuxSha) {
            if ($script:WindowsMainTfSha -eq $linuxSha.ToLower()) { Add-Pass 'infra/main.tf' 'C:\terraform\main.tf is identical to the bundled infra/main.tf, so the lab was provisioned from this bundle.' }
            else { Add-Warn 'infra/main.tf' 'C:\terraform\main.tf differs from the bundled infra/main.tf. The foundation was provisioned from a different revision than the lab files.' }
        } elseif (-not $script:WindowsMainTfSha) {
            Add-Info 'infra/main.tf' 'C:\terraform\main.tf is not on this VM, so the provisioned revision cannot be compared with the bundle.'
        }
    }

    if ($LockFacts) {
        Add-Info 'Pinned application' ('image {0}, native OTLP {1}' -f $LockFacts.ImageTag, $LockFacts.NativeOtlp)
        if ($LockFacts.Rehearsal -eq 'pending') { Add-Info 'Rehearsal status' 'setup/artifact-lock.json still says rehearsal.status is "pending".' }
        $bsExists = Get-BlockOut $toolBlocks 'bs_exists'
        if ($bsExists -ne 'yes') {
            Add-Fail 'Backstage runtime' ('{0}/runtime/backstage is missing. Prepare the image with make setup before Skillable places the state, or the first learner make setup downloads it.' -f $labRootShown)
        } else {
            $rev = Get-BlockOut $toolBlocks 'bs_rev'
            if ($rev -eq $LockFacts.BackstageRev) { Add-Pass 'Backstage revision' ($rev.Substring(0, 12) + ' (pinned in setup/artifact-lock.json)') }
            else { Add-Fail 'Backstage revision' ("Checked out '{0}', pinned '{1}'. fast-track.sh refuses a different revision." -f (Limit-Text $rev 40), $LockFacts.BackstageRev) }
            if ((Get-BlockOut $toolBlocks 'bs_modules') -eq 'yes') { Add-Pass 'Backstage dependencies' 'Installed completely (node_modules/.yarn-state.yml exists).' }
            else { Add-Fail 'Backstage dependencies' 'node_modules/.yarn-state.yml is missing, so the Yarn install did not finish. Rerun make setup, or run the Yarn install in runtime/backstage.' }
            $yarnFiles = Get-BlockOut $toolBlocks 'bs_yarn'
            if ($yarnFiles -match [regex]::Escape('yarn-' + $LockFacts.Yarn + '.cjs')) { Add-Pass 'Yarn release' ('yarn-{0}.cjs is present.' -f $LockFacts.Yarn) }
            else { Add-Fail 'Yarn release' ('.yarn/releases has no yarn-{0}.cjs. start-backstage.sh runs it.' -f $LockFacts.Yarn) }
            if ((Get-BlockOut $toolBlocks 'bs_override') -eq 'same') { Add-Pass 'Backstage lab overrides' 'App.tsx and index.ts match src/backstage.' }
            else { Add-Fail 'Backstage lab overrides' 'App.tsx or index.ts differs from src/backstage. fast-track.sh copies them during preparation.' }
        }
    } else {
        Add-Fail 'artifact-lock.json' 'Could not read setup/artifact-lock.json (missing file, or jq is not working).'
    }
}

# ---------------------------------------------------------------------------------------------------------
# 5. Network from WSL
# ---------------------------------------------------------------------------------------------------------

Start-Section '5. Network from WSL'

if (-not $script:WslOk) {
    Add-Skip 'Network checks' 'WSL is not available.'
} else {
    $urls = @()
    foreach ($t in $NetworkTargets) { $urls += @{ Name = $t.Name; Url = $t.Url; Insecure = $false } }
    if ($LabOut) {
        $ws = [string](Get-Prop $LabOut @('WORKLOAD_SERVER'))
        if ($ws -match '^https://[A-Za-z0-9.:-]+$') { $urls += @{ Name = 'Workload cluster API server'; Url = ($ws.TrimEnd('/') + '/version'); Insecure = $true } }
    }
    if ($stateSummary -and $stateSummary.ControlHost -match '^https://[A-Za-z0-9.:-]+$') {
        $urls += @{ Name = 'Control cluster API server'; Url = ($stateSummary.ControlHost.TrimEnd('/') + '/version'); Insecure = $true }
    }
    $netScript = New-BashEnv ([ordered]@{ URLS = (($urls | ForEach-Object { $_.Url }) -join ' ') })
    $netScript += @'
i=0
for u in $URLS; do
  i=$((i+1))
  run "net_$i" sh -c 'curl -sSk -o /dev/null -w "%{http_code}" --max-time 15 "$1"' _ "$u"
done
'@
    $nb = Invoke-WslBatch -Script $netScript -TimeoutSec 240
    if ($null -eq $nb) {
        Add-Fail 'Network checks' $script:BatchError
    } else {
        for ($i = 0; $i -lt $urls.Count; $i++) {
            $b = Get-Block $nb ('net_' + ($i + 1))
            $code = ''
            if ($b) { $code = $b.Out.Trim() }
            if ($code -match '^[1-5]\d\d$') { Add-Pass ('Reach ' + $urls[$i].Name) ('HTTP {0} from {1}' -f $code, ($urls[$i].Url -replace '^(https://[^/]+).*$', '$1')) }
            else { Add-Fail ('Reach ' + $urls[$i].Name) ('No answer from {0}. {1}' -f $urls[$i].Url, (Limit-Text $(if ($b) { $b.Err } else { '' }) 120)) }
        }
    }
}

# ---------------------------------------------------------------------------------------------------------
# 6. Azure foundation
# ---------------------------------------------------------------------------------------------------------

Start-Section '6. Azure foundation (needs az login in WSL)'

$azureSignedIn = $false
$azureReady = $false
$ctlJson = $null
if ($SkipAzure) {
    Add-Skip 'Azure checks' '-SkipAzure was given.'
    $script:AzureSkipReason = '-SkipAzure'
} elseif (-not $script:WslOk) {
    Add-Skip 'Azure checks' 'WSL is not available.'
    $script:AzureSkipReason = 'WSL is not available'
} elseif ($null -eq $LabOut) {
    Add-Skip 'Azure checks' 'The state has no lab output, so the resource names are unknown.'
    $script:AzureSkipReason = 'no lab output in the state'
} else {
    $sub = [string](Get-Prop $LabOut @('AZURE_SUBSCRIPTION_ID'))
    $ten = [string](Get-Prop $LabOut @('AZURE_TENANT_ID'))
    $rg = [string](Get-Prop $LabOut @('AKS_RESOURCE_GROUP'))
    $ctl = [string](Get-Prop $LabOut @('CONTROL_CLUSTER_NAME'))
    $wkl = [string](Get-Prop $LabOut @('AKS_CLUSTER_NAME'))
    $labId = [string](Get-Prop $LabOut @('LAB_ID'))
    $modelId = [string](Get-Prop $LabOut @('MODEL_RESOURCE_ID'))
    $modelName = ($modelId -split '/')[-1]
    $envMap = [ordered]@{
        SUB = $sub; TEN = $ten; RG = $rg; CTL = $ctl; WKL = $wkl; LAB = $labId; MODEL = $modelName
        DEPLOY = [string](Get-Prop $LabOut @('MODEL_DEPLOYMENT')); LAW_ID = [string](Get-Prop $LabOut @('LOG_ANALYTICS_WORKSPACE_ID'))
        AMW_ID = [string](Get-Prop $LabOut @('AZURE_MONITOR_WORKSPACE_ID')); SA = [string](Get-Prop $LabOut @('STATE_ACCOUNT'))
        SC = [string](Get-Prop $LabOut @('STATE_CONTAINER')); AKS_API = $AksApiVersion; CMD_TIMEOUT = '120'
    }
    $acctScript = (New-BashEnv $envMap) + @'
run acct az account show -o json
run me T az ad signed-in-user show --query id -o tsv
'@
    $ab = $null
    try { $ab = Invoke-WslBatch -Script $acctScript -TimeoutSec 120 } catch { $script:BatchError = $_.Exception.Message }
    if ($null -eq $ab) {
        Add-Fail 'Azure CLI in WSL' $script:BatchError
        $script:AzureSkipReason = 'WSL commands failed'
    } else {
        $acct = ConvertFrom-JsonSafe (Get-BlockOut $ab 'acct')
        if ($null -eq $acct) {
            $e = Get-Block $ab 'acct'
            Add-Skip 'Azure checks' 'Azure CLI in WSL is not signed in, so Azure and Kubernetes were not checked. Sign in as the lab account (az login --use-device-code), then run this script again.'
            if ($e -and $e.Err) { Add-Info 'az account show' (Limit-Text $e.Err 200) }
            $script:AzureSkipReason = 'az is not signed in'
        } else {
            $azureSignedIn = $true
            $actSub = [string](Get-Prop $acct @('id'))
            $actTen = [string](Get-Prop $acct @('tenantId'))
            if ($actSub -eq $sub -and $actTen -eq $ten) { Add-Pass 'Azure sign-in' ('Active subscription and tenant match the provisioned outputs (user {0}).' -f (Get-Prop $acct @('user', 'name'))) }
            else {
                Add-Fail 'Azure sign-in' ('The active subscription/tenant ({0} / {1}) do not match the state ({2} / {3}). bootstrap.sh stops on this. Select the assigned subscription.' -f $actSub, $actTen, $sub, $ten)
            }
            if ((Get-Prop $acct @('state')) -and (Get-Prop $acct @('state')) -ne 'Enabled') { Add-Fail 'Subscription state' ('The subscription is ' + (Get-Prop $acct @('state'))) }
            $me = Get-BlockOut $ab 'me'
            if (-not $me) { Add-Info 'Signed-in user' 'Could not read the signed-in user object ID (Microsoft Graph), so cluster-operator membership was not checked.' }
            elseif ($OperatorIds.Count -gt 0) {
                if ($OperatorIds -contains $me.Trim()) { Add-Pass 'Signed-in user is a cluster operator' 'Listed in CLUSTER_OPERATOR_OBJECT_IDS, so the clusters accept this sign-in.' }
                else { Add-Warn 'Signed-in user is a cluster operator' 'This sign-in is not in CLUSTER_OPERATOR_OBJECT_IDS (the learner or bootstrap identity). It will not have cluster access.' }
            }

            $azScript = (New-BashEnv $envMap) + @'
CTL_ID="/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.ContainerService/managedClusters/$CTL"
WKL_ID="/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.ContainerService/managedClusters/$WKL"
SA_ID="/subscriptions/$SUB/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA"
run rg T az group show -n "$RG" --subscription "$SUB" -o json
run aks_ctl T az rest --method get --url "https://management.azure.com$CTL_ID?api-version=$AKS_API" -o json || run aks_ctl T az aks show -g "$RG" -n "$CTL" --subscription "$SUB" -o json
run aks_wkl T az rest --method get --url "https://management.azure.com$WKL_ID?api-version=$AKS_API" -o json || run aks_wkl T az aks show -g "$RG" -n "$WKL" --subscription "$SUB" -o json
run model T az cognitiveservices account show -g "$RG" -n "$MODEL" --subscription "$SUB" -o json
run deployment T az cognitiveservices account deployment show -g "$RG" -n "$MODEL" --deployment-name "$DEPLOY" --subscription "$SUB" -o json
run law T az resource show --ids "$LAW_ID" -o json
run amw T az resource show --ids "$AMW_ID" -o json
run storage T az storage account show -g "$RG" -n "$SA" --subscription "$SUB" -o json
run container T az resource show --ids "$SA_ID/blobServices/default/containers/$SC" -o json
run identities T az identity list -g "$RG" --subscription "$SUB" --query "[].name" -o tsv
run fed_prov T az identity federated-credential list --identity-name "id-prel37-$LAB-provisioner" -g "$RG" --subscription "$SUB" -o json
run fed_argo T az identity federated-credential list --identity-name "id-prel37-$LAB-argocd" -g "$RG" --subscription "$SUB" -o json
run feature T az feature show --namespace Microsoft.Insights --name OtlpApplicationInsights --query properties.state -o tsv
run providers T az provider list --query "[].[namespace,registrationState]" -o tsv
run roles_ctl T az role assignment list --scope "$CTL_ID" --query "[].{p:principalId,r:roleDefinitionName}" -o json
run roles_wkl T az role assignment list --scope "$WKL_ID" --query "[].{p:principalId,r:roleDefinitionName}" -o json
'@
            Write-Line 'Reading Azure resources (this can take a minute or two)...' 'DarkGray'
            $zb = Invoke-WslBatch -Script $azScript -TimeoutSec $AzureTimeoutSeconds
            if ($null -eq $zb) {
                Add-Fail 'Azure resource checks' $script:BatchError
            } else {
                $azureReady = $true
                $failText = { param($key) $b = Get-Block $zb $key; if ($b) { Limit-Text $b.Err 200 } else { 'no result' } }

                $rgj = ConvertFrom-JsonSafe (Get-BlockOut $zb 'rg')
                if ($rgj) { Add-Pass 'Resource group' ('{0} exists in {1}' -f $rg, (Get-Prop $rgj @('location'))) } else { Add-Fail 'Resource group' ('{0}: {1}' -f $rg, (& $failText 'rg')) }

                foreach ($c in @(@{ Key = 'aks_ctl'; Name = $ctl; Role = 'control (AKS Standard)'; Auto = $false }, @{ Key = 'aks_wkl'; Name = $wkl; Role = 'workload (AKS Automatic)'; Auto = $true })) {
                    $j = ConvertFrom-JsonSafe (Get-BlockOut $zb $c.Key)
                    if (-not $j) { Add-Fail ('AKS ' + $c.Role) ('{0}: {1}' -f $c.Name, (& $failText $c.Key)); continue }
                    $ps = Get-AksProp $j @('provisioningState')
                    $pw = Get-AksProp $j @('powerState', 'code')
                    if ($ps -eq 'Succeeded' -and $pw -eq 'Running') { Add-Pass ('AKS ' + $c.Role) ('{0}: provisioning Succeeded, power Running' -f $c.Name) }
                    else { Add-Fail ('AKS ' + $c.Role) ('{0}: provisioning {1}, power {2}' -f $c.Name, $ps, $pw) }
                    $skuName = Get-Prop $j @('sku', 'name'); $skuTier = Get-Prop $j @('sku', 'tier')
                    if ($c.Auto) {
                        if ($skuName -eq 'Automatic') { Add-Pass 'Workload cluster SKU' 'Automatic' } else { Add-Fail 'Workload cluster SKU' ("sku.name is '{0}'; the lab expects AKS Automatic." -f $skuName) }
                        $lvl = Get-AksProp $j @('safeguardsProfile', 'level')
                        if ($lvl -eq 'Enforcement') { Add-Pass 'Deployment Safeguards' 'Level is Enforcement, so Module 5 rejects the latest tag.' }
                        elseif ($lvl) { Add-Fail 'Deployment Safeguards' ("Level is '{0}'. Module 5 expects Enforcement, or the latest tag is admitted." -f $lvl) }
                        else { Add-Warn 'Deployment Safeguards' 'The level is not reported. infra/main.tf does not set it explicitly; confirm it is Enforcement before Module 5.' }
                        $gw = Get-AksProp $j @('ingressProfile', 'gatewayAPI', 'installation')
                        $ist = Get-AksProp $j @('ingressProfile', 'webAppRouting', 'gatewayAPIImplementations', 'appRoutingIstio', 'mode')
                        if ($gw -eq 'Standard' -and $ist -eq 'Enabled') { Add-Pass 'Gateway API and App Routing (Istio)' 'Standard channel installed; Istio implementation enabled.' }
                        else { Add-Fail 'Gateway API and App Routing (Istio)' ("gatewayAPI.installation='{0}', appRoutingIstio.mode='{1}'. The shared Gateway needs both." -f $gw, $ist) }
                        $ci = Get-AksProp $j @('azureMonitorProfile', 'containerInsights', 'enabled')
                        $mp = Get-AksProp $j @('azureMonitorProfile', 'metrics', 'enabled')
                        if ($ci -eq $true -and $mp -eq $true) { Add-Pass 'Workload cluster monitoring' 'Container Insights and managed metrics are enabled.' }
                        else { Add-Warn 'Workload cluster monitoring' ("containerInsights.enabled='{0}', metrics.enabled='{1}' (infra/main.tf enables both)." -f $ci, $mp) }
                    } else {
                        $ctlJson = $j
                        if ($skuTier -eq 'Free') { Add-Pass 'Control cluster tier' 'Free' } else { Add-Warn 'Control cluster tier' ("sku.tier is '{0}'; infra/main.tf uses Free." -f $skuTier) }
                        $oidc = Get-AksProp $j @('oidcIssuerProfile', 'enabled')
                        $wi = Get-AksProp $j @('securityProfile', 'workloadIdentity', 'enabled')
                        if ($oidc -eq $true -and $wi -eq $true) { Add-Pass 'Control cluster identity' 'OIDC issuer and workload identity are enabled.' } else { Add-Fail 'Control cluster identity' ("oidcIssuer='{0}', workloadIdentity='{1}'. Crossplane and Argo CD authenticate with workload identity." -f $oidc, $wi) }
                        $rbac = Get-AksProp $j @('aadProfile', 'enableAzureRBAC')
                        $local = Get-AksProp $j @('disableLocalAccounts')
                        if ($rbac -eq $true -and $local -eq $true) { Add-Pass 'Control cluster access' 'Azure RBAC on, local accounts disabled (kubelogin with the Azure CLI works).' } else { Add-Warn 'Control cluster access' ("enableAzureRBAC='{0}', disableLocalAccounts='{1}'" -f $rbac, $local) }
                    }
                }

                $mj = ConvertFrom-JsonSafe (Get-BlockOut $zb 'model')
                if ($mj) {
                    $mps = Get-Prop $mj @('properties', 'provisioningState')
                    if ($mps -eq 'Succeeded') { Add-Pass 'Azure OpenAI account' ('{0}: Succeeded' -f $modelName) } else { Add-Fail 'Azure OpenAI account' ('{0}: {1}' -f $modelName, $mps) }
                } else { Add-Fail 'Azure OpenAI account' ('{0}: {1}' -f $modelName, (& $failText 'model')) }
                $dj = ConvertFrom-JsonSafe (Get-BlockOut $zb 'deployment')
                if ($dj) {
                    $dps = Get-Prop $dj @('properties', 'provisioningState')
                    $mn = Get-Prop $dj @('properties', 'model', 'name'); $mv = Get-Prop $dj @('properties', 'model', 'version')
                    $cap = Get-Prop $dj @('sku', 'capacity')
                    if ($dps -eq 'Succeeded') { Add-Pass 'Model deployment' ('lab-model: {0} {1}, capacity {2}' -f $mn, $mv, $cap) } else { Add-Fail 'Model deployment' ('{0}: provisioning {1}' -f $envMap.DEPLOY, $dps) }
                } else { Add-Fail 'Model deployment' ('{0}: {1}' -f $envMap.DEPLOY, (& $failText 'deployment')) }

                $lj = ConvertFrom-JsonSafe (Get-BlockOut $zb 'law')
                if ($lj -and (Get-Prop $lj @('properties', 'customerId'))) { Add-Pass 'Log Analytics workspace' 'Exists and reports a customerId (Module 3 queries it).' } else { Add-Fail 'Log Analytics workspace' (& $failText 'law') }
                if (ConvertFrom-JsonSafe (Get-BlockOut $zb 'amw')) { Add-Pass 'Azure Monitor workspace' 'Exists.' } else { Add-Fail 'Azure Monitor workspace' (& $failText 'amw') }
                $sj = ConvertFrom-JsonSafe (Get-BlockOut $zb 'storage')
                if ($sj) { Add-Pass 'State storage account' ('{0}: {1}' -f $envMap.SA, (Get-Prop $sj @('provisioningState'))) } else { Add-Fail 'State storage account' ('{0}: {1}' -f $envMap.SA, (& $failText 'storage')) }
                if (ConvertFrom-JsonSafe (Get-BlockOut $zb 'container')) { Add-Pass 'State container' ($envMap.SC + ' exists') } else { Add-Fail 'State container' ('{0}: {1}' -f $envMap.SC, (& $failText 'container')) }

                $idNames = (Get-BlockOut $zb 'identities')
                $idList = @()
                if ($idNames) { $idList = @($idNames -split "\s+" | Where-Object { $_ }) }
                $wantIds = @("id-prel37-$labId-provisioner", "id-prel37-$labId-argocd")
                $lacking = @($wantIds | Where-Object { $idList -notcontains $_ })
                if ($lacking.Count -eq 0) { Add-Pass 'Managed identities' ($wantIds -join ', ') } else { Add-Fail 'Managed identities' ('Missing: ' + ($lacking -join ', ')) }
                $issuer = [string](Get-AksProp $ctlJson @('oidcIssuerProfile', 'issuerURL'))
                foreach ($f in @(@{ Key = 'fed_prov'; Want = 1; Name = 'provisioner' }, @{ Key = 'fed_argo'; Want = 2; Name = 'argocd' })) {
                    $fj = ConvertFrom-JsonSafe (Get-BlockOut $zb $f.Key)
                    $creds = @($fj)
                    if ($null -eq $fj -or $creds.Count -lt $f.Want) { Add-Fail ('Federated credentials: ' + $f.Name) ('Found {0}, expected {1}. {2}' -f $creds.Count, $f.Want, (& $failText $f.Key)) }
                    else {
                        $stale = @($creds | Where-Object { $issuer -and ([string]$_.issuer).TrimEnd('/') -ne $issuer.TrimEnd('/') })
                        if ($stale.Count -gt 0) { Add-Fail ('Federated credentials: ' + $f.Name) 'Issuer does not match the control cluster OIDC issuer, so workload identity would fail.' }
                        else { Add-Pass ('Federated credentials: ' + $f.Name) ('{0} credential(s), issuer matches the control cluster' -f $creds.Count) }
                    }
                }

                $feat = Get-BlockOut $zb 'feature'
                if ($feat -and $feat.Trim() -eq 'Registered') { Add-Pass 'Preview feature Microsoft.Insights/OtlpApplicationInsights' 'Registered.' }
                else { Add-Fail 'Preview feature Microsoft.Insights/OtlpApplicationInsights' ("State is '{0}'. Module 2 vends OTLP-enabled Application Insights, which needs it. {1}" -f $(if ($feat) { $feat.Trim() } else { 'unknown' }), (& $failText 'feature')) }
                $provText = Get-BlockOut $zb 'providers'
                if ($provText) {
                    $reg = @{}
                    foreach ($line in ($provText -split "`n")) { $p = $line -split "`t"; if ($p.Count -ge 2) { $reg[$p[0].Trim()] = $p[1].Trim() } }
                    $notReg = @($RequiredProviders | Where-Object { $reg[$_] -ne 'Registered' })
                    if ($notReg.Count -eq 0) { Add-Pass 'Resource providers' ('Registered: ' + ($RequiredProviders -join ', ')) }
                    else { Add-Warn 'Resource providers' ('Not Registered in this subscription: ' + (($notReg | ForEach-Object { '{0} ({1})' -f $_, $(if ($reg[$_]) { $reg[$_] } else { 'unknown' }) }) -join ', ')) }
                } else { Add-Warn 'Resource providers' ('Could not list them. ' + (& $failText 'providers')) }

                # Cluster roles for every operator (infra/main.tf operator_cluster_access and operator_cluster_credentials).
                foreach ($rc in @(@{ Key = 'roles_ctl'; Name = 'control' }, @{ Key = 'roles_wkl'; Name = 'workload' })) {
                    $rj = ConvertFrom-JsonSafe (Get-BlockOut $zb $rc.Key)
                    if ($null -eq $rj) { Add-Warn ('Cluster roles on the ' + $rc.Name + ' cluster') ('Could not read role assignments. ' + (& $failText $rc.Key)); continue }
                    $assigns = @($rj)
                    $problems = @()
                    foreach ($op in $OperatorIds) {
                        $roles = @($assigns | Where-Object { $_.p -eq $op } | ForEach-Object { $_.r })
                        foreach ($need in @('Azure Kubernetes Service RBAC Cluster Admin', 'Azure Kubernetes Service Cluster User Role')) {
                            if ($roles -notcontains $need) { $problems += ('{0} lacks {1}' -f $op.Substring(0, [Math]::Min(8, $op.Length)), $need) }
                        }
                    }
                    if ($OperatorIds.Count -eq 0) { Add-Info ('Cluster roles on the ' + $rc.Name + ' cluster') 'No operator IDs in the state to check.' }
                    elseif ($problems.Count -gt 0) { Add-Fail ('Cluster roles on the ' + $rc.Name + ' cluster') ($problems -join '; ') }
                    else { Add-Pass ('Cluster roles on the ' + $rc.Name + ' cluster') ('Cluster Admin and Cluster User for all {0} operator(s)' -f $OperatorIds.Count) }
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------------------------------------
# 7. Kubernetes foundation
# ---------------------------------------------------------------------------------------------------------

Start-Section '7. Kubernetes foundation (needs az login in WSL)'

if ($SkipAzure -or $SkipKubernetes) {
    Add-Skip 'Kubernetes checks' $(if ($SkipAzure) { '-SkipAzure was given.' } else { '-SkipKubernetes was given.' })
} elseif (-not $azureSignedIn -or -not $azureReady) {
    Add-Skip 'Kubernetes checks' $(if ($script:AzureSkipReason) { "Not run: $($script:AzureSkipReason)." } else { 'Not run: the Azure checks did not complete.' })
} else {
    $kScript = (New-BashEnv $envMap) + @'
KC="$(mktemp)"
export KUBECONFIG="$KC"
run kc_ctl T az aks get-credentials --subscription "$SUB" -g "$RG" -n "$CTL" --file "$KC" --context chk-control --overwrite-existing
run kc_wkl T az aks get-credentials --subscription "$SUB" -g "$RG" -n "$WKL" --file "$KC" --context chk-workload --overwrite-existing
run kc_login kubelogin convert-kubeconfig --login azurecli --kubeconfig "$KC"
NODES='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Ready")]}{.status}{end}{"\n"}{end}'
run ctl_nodes T kubectl --request-timeout=30s --context chk-control get nodes -o jsonpath="$NODES"
run ctl_crossplane T kubectl --request-timeout=30s --context chk-control -n crossplane-system get deploy -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.availableReplicas}{"/"}{.spec.replicas}{"\n"}{end}'
run ctl_xrd T kubectl --request-timeout=30s --context chk-control get crd compositeresourcedefinitions.apiextensions.crossplane.io -o name
run ctl_argocd T kubectl --request-timeout=30s --context chk-control -n argocd get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{range .status.containerStatuses[*]}{.ready}{" "}{end}{"\n"}{end}'
run ctl_argocd_secret T kubectl --request-timeout=30s --context chk-control -n argocd get secret argocd-initial-admin-secret -o name
run wkl_nodes T kubectl --request-timeout=30s --context chk-workload get nodes -o jsonpath="$NODES"
run wkl_gwcrd T kubectl --request-timeout=30s --context chk-workload get crd gateways.gateway.networking.k8s.io -o name
run wkl_gwclass T kubectl --request-timeout=30s --context chk-workload get gatewayclass -o name
'@
    Write-Line 'Reading both clusters (this can take a minute)...' 'DarkGray'
    $kb = Invoke-WslBatch -Script $kScript -TimeoutSec $AzureTimeoutSeconds
    if ($null -eq $kb) {
        Add-Fail 'Kubernetes checks' $script:BatchError
    } else {
        $kFail = { param($key) $b = Get-Block $kb $key; if ($b) { Limit-Text $b.Err 220 } else { 'no result' } }
        if ($null -ne (Get-BlockOut $kb 'kc_ctl') -and $null -ne (Get-BlockOut $kb 'kc_wkl')) { Add-Pass 'Cluster credentials' 'az aks get-credentials worked for both clusters (temporary kubeconfig).' }
        else { Add-Fail 'Cluster credentials' ('control: {0} | workload: {1}' -f (& $kFail 'kc_ctl'), (& $kFail 'kc_wkl')) }

        function Test-Nodes {
            param([string]$Key, [string]$Label)
            $t = Get-BlockOut $kb $Key
            if ($null -eq $t) { Add-Fail ($Label + ' nodes') (& $kFail $Key); return }
            $rows = @($t -split "`n" | Where-Object { $_ })
            $ready = @($rows | Where-Object { ($_ -split "`t")[1] -eq 'True' })
            if ($rows.Count -ge 1 -and $ready.Count -eq $rows.Count) { Add-Pass ($Label + ' nodes') ('{0} node(s), all Ready' -f $rows.Count) }
            else { Add-Fail ($Label + ' nodes') ('{0} of {1} node(s) Ready' -f $ready.Count, $rows.Count) }
        }
        Test-Nodes 'ctl_nodes' 'Control cluster'
        Test-Nodes 'wkl_nodes' 'Workload cluster'

        $cp = Get-BlockOut $kb 'ctl_crossplane'
        if ($null -eq $cp) { Add-Fail 'Crossplane (Terraform-installed)' (& $kFail 'ctl_crossplane') }
        else {
            $bad = @($cp -split "`n" | Where-Object { $_ } | Where-Object { $p = ($_ -split "`t")[1]; $p -notmatch '^(\d+)/\1$' -or $p -match '^0/' })
            $names = @($cp -split "`n" | Where-Object { $_ } | ForEach-Object { ($_ -split "`t")[0] })
            if ($names -contains 'crossplane' -and $bad.Count -eq 0) { Add-Pass 'Crossplane (Terraform-installed)' ('Deployments available: ' + ($names -join ', ')) }
            else { Add-Fail 'Crossplane (Terraform-installed)' ('Not fully available: ' + ($(if ($bad.Count -gt 0) { $bad -join '; ' } else { 'no crossplane Deployment in crossplane-system' }))) }
        }
        if ($null -ne (Get-BlockOut $kb 'ctl_xrd')) { Add-Pass 'Crossplane CRDs' 'compositeresourcedefinitions.apiextensions.crossplane.io exists.' } else { Add-Fail 'Crossplane CRDs' (& $kFail 'ctl_xrd') }

        $ap = Get-BlockOut $kb 'ctl_argocd'
        if ($null -eq $ap) { Add-Fail 'Argo CD (AKS extension)' (& $kFail 'ctl_argocd') }
        else {
            $pods = @($ap -split "`n" | Where-Object { $_ })
            $notRunning = @($pods | Where-Object { $f = $_ -split "`t"; $f[1] -ne 'Running' -or ($f.Count -gt 2 -and $f[2] -match 'false') } | ForEach-Object { ($_ -split "`t")[0] })
            $needed = @('argocd-application-controller', 'argocd-server', 'argocd-repo-server')
            $lackingPods = @($needed | Where-Object { $n2 = $_; -not ($pods | Where-Object { $_ -like "$n2*" }) })
            if ($lackingPods.Count -gt 0) { Add-Fail 'Argo CD (AKS extension)' ('No pod for: ' + ($lackingPods -join ', ')) }
            elseif ($notRunning.Count -gt 0) { Add-Fail 'Argo CD (AKS extension)' ('Not running and ready: ' + ($notRunning -join ', ')) }
            else { Add-Pass 'Argo CD (AKS extension)' ('{0} pods running and ready' -f $pods.Count) }
        }
        if ($null -ne (Get-BlockOut $kb 'ctl_argocd_secret')) { Add-Pass 'Argo CD admin secret' 'argocd-initial-admin-secret exists (make argocd prints the password from it).' }
        else { Add-Warn 'Argo CD admin secret' 'argocd-initial-admin-secret was not found, so make argocd cannot print the admin password.' }

        if ($null -ne (Get-BlockOut $kb 'wkl_gwcrd')) { Add-Pass 'Gateway API CRDs (workload)' 'gateways.gateway.networking.k8s.io exists.' } else { Add-Fail 'Gateway API CRDs (workload)' (& $kFail 'wkl_gwcrd') }
        $gc = Get-BlockOut $kb 'wkl_gwclass'
        if ($gc) { Add-Pass 'GatewayClass (workload)' (($gc -split "`n" | Where-Object { $_ }) -join ', ') } else { Add-Fail 'GatewayClass (workload)' ('No GatewayClass, so the shared Gateway cannot be programmed. ' + (& $kFail 'wkl_gwclass')) }
    }
}

# ---------------------------------------------------------------------------------------------------------
# 8. Learner setup
# ---------------------------------------------------------------------------------------------------------

Start-Section '8. Learner setup (what make setup, make auth, and the local services leave behind)'

$flags = @{}
if ($script:WslOk -and $toolBlocks) {
    $ff = Get-BlockOut $toolBlocks 'learner_flags'
    if ($ff) { foreach ($line in ($ff -split "`n")) { $kv = $line -split '=', 2; if ($kv.Count -eq 2) { $flags[$kv[0].Trim()] = $kv[1].Trim() } } }
}
$setupStarted = ($flags['config/lab.env'] -eq 'yes') -or ($flags['config/lab.json'] -eq 'yes')

if (-not $IncludeLearnerSetup) {
    if (-not $script:WslOk) { Add-Skip 'Learner setup' 'WSL results are not available.' }
    elseif ($setupStarted) { Add-Info 'Learner setup' 'make setup has already run on this VM (config/lab.env exists). Run with -IncludeLearnerSetup to verify it.' }
    else { Add-Info 'Learner setup' 'Not started. That is the expected state before an attendee begins. Use -IncludeLearnerSetup after an attendee finishes setup.' }
    if ($flags['.credentials/read-token'] -eq 'yes' -or $flags['.credentials/backstage-token'] -eq 'yes') {
        Add-Warn 'Credentials on the image' '~/prel37/.credentials already holds a token. Remove tokens and sign-ins before snapshotting a reusable image.'
    }
} elseif (-not $script:WslOk) {
    Add-Skip 'Learner setup' 'WSL is not available.'
} else {
    $fileChecks = @('config/lab.json', 'config/lab.env', 'config/setup.env', 'config/environment.yaml', 'config/artifact-lock.json', '.state/kubeconfig', 'prel37.code-workspace',
        'answers/product-brief.md', 'exercises/application/values.yaml', 'exercises/application/profile.yaml', 'queries/application-model-call.kql', 'evidence/profile-comparison.md',
        'platform/.git', 'app-deploy/.git', 'runtime/backstage/app-config.local.yaml')
    $absentFiles = @($fileChecks | Where-Object { $flags[$_] -ne 'yes' })
    if ($absentFiles.Count -gt 0) { Add-Fail 'Workspace files' ('Missing or empty under ~/prel37: ' + ($absentFiles -join ', ') + '. make setup did not finish.') }
    else { Add-Pass 'Workspace files' ('All {0} files and folders make setup creates are present.' -f $fileChecks.Count) }
    foreach ($t in @('read-token', 'backstage-token')) {
        if ($flags['.credentials/' + $t] -eq 'yes') { Add-Pass ('Credential file: ' + $t) 'Present and nonempty (contents not read).' }
        else { Add-Fail ('Credential file: ' + $t) 'Missing or empty. make auth has not run, or it failed.' }
    }

    $lScript = (New-BashEnv ([ordered]@{ LAB_ROOT_OVERRIDE = $(if ($LabRoot) { $LabRoot } else { '' }); CMD_TIMEOUT = '90' })) + @'
LAB_ROOT="${LAB_ROOT_OVERRIDE:-$HOME/prel37}"
KCFG="$LAB_ROOT/.state/kubeconfig"
run lab_json sh -c 'jq -r "[.LAB_ID,.AZURE_SUBSCRIPTION_ID,.AZURE_TENANT_ID] | @tsv" "$1/config/lab.json"' _ "$LAB_ROOT"
run setup_env sh -c '. "$1/config/setup.env" 2>/dev/null; printf "%s\t%s\t%s" "$OWNER" "${GIT_NAME:+set}" "${GIT_EMAIL:+set}"' _ "$LAB_ROOT"
run perms sh -c 'stat -c "%a" "$1/.credentials/read-token" "$1/.credentials/backstage-token" "$1/.credentials" | tr "\n" " "' _ "$LAB_ROOT"
run url_platform git -C "$LAB_ROOT/platform" remote get-url origin
run url_app git -C "$LAB_ROOT/app-deploy" remote get-url origin
run branch_platform git -C "$LAB_ROOT/platform" rev-parse --abbrev-ref HEAD
run branch_app git -C "$LAB_ROOT/app-deploy" rev-parse --abbrev-ref HEAD
run dirty_platform sh -c 'git -C "$1" status --porcelain | wc -l' _ "$LAB_ROOT/platform"
run dirty_app sh -c 'git -C "$1" status --porcelain | wc -l' _ "$LAB_ROOT/app-deploy"
run git_identity sh -c 'printf "%s\t%s" "$(git -C "$1" config user.name)" "$(git -C "$1" config user.email)"' _ "$LAB_ROOT/platform"
run gh_ok sh -c 'gh auth status >/dev/null 2>&1 && echo ok || echo no'
run gh_user sh -c 'gh api user --jq .login 2>/dev/null'
run contexts sh -c 'KUBECONFIG="$1" kubectl config get-contexts -o name' _ "$KCFG"
run provider T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control get providers.pkg.crossplane.io provider-opentofu -o jsonpath='{range .status.conditions[?(@.type=="Healthy")]}{.status}{end}'
run functions T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control get functions.pkg.crossplane.io -l app.kubernetes.io/part-of=prel37 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[?(@.type=="Healthy")]}{.status}{end}{"\n"}{end}'
run gateway T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-workload -n platform-gateway get gateway tenants -o jsonpath='{range .status.conditions[?(@.type=="Programmed")]}{.status}{end}'
run sec_git T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control -n crossplane-system get secret module-git-credentials -o name
run sec_platform T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control -n argocd get secret repo-platform -o name
run sec_app T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control -n argocd get secret repo-app-deploy -o name
run sec_cluster T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control -n argocd get secret cluster-workload -o name
run sec_token T kubectl --kubeconfig "$KCFG" --request-timeout=30s --context prel37-control -n platform-system get secret github-token -o name
'@
    Write-Line 'Reading the learner setup state (this can take a minute)...' 'DarkGray'
    $lb = Invoke-WslBatch -Script $lScript -TimeoutSec $AzureTimeoutSeconds
    if ($null -eq $lb) {
        Add-Fail 'Learner setup checks' $script:BatchError
    } else {
        $lFail = { param($key) $b = Get-Block $lb $key; if ($b) { Limit-Text $b.Err 200 } else { 'no result' } }
        $lj = Get-BlockOut $lb 'lab_json'
        if ($lj -and $LabOut) {
            $f = $lj -split "`t"
            if ($f.Count -ge 3 -and $f[0] -eq [string](Get-Prop $LabOut @('LAB_ID')) -and $f[1] -eq [string](Get-Prop $LabOut @('AZURE_SUBSCRIPTION_ID')) -and $f[2] -eq [string](Get-Prop $LabOut @('AZURE_TENANT_ID'))) { Add-Pass 'config/lab.json' 'Lab ID, subscription, and tenant match the bootstrap state.' }
            else { Add-Fail 'config/lab.json' 'Does not match the bootstrap state. This workspace was configured for another lab.' }
        } elseif ($lj) { Add-Info 'config/lab.json' 'Present (no bootstrap state to compare with).' }
        else { Add-Fail 'config/lab.json' (& $lFail 'lab_json') }

        $se = Get-BlockOut $lb 'setup_env'
        $owner = ''
        if ($se) {
            $f = $se -split "`t"
            $owner = $f[0]
            if ($f.Count -ge 3 -and $owner -and $f[1] -eq 'set' -and $f[2] -eq 'set') { Add-Pass 'config/setup.env' ("OWNER '{0}', Git author name and email are set." -f $owner) }
            else { Add-Fail 'config/setup.env' 'OWNER, GIT_NAME, and GIT_EMAIL must all be set.' }
        } else { Add-Fail 'config/setup.env' (& $lFail 'setup_env') }
        if ($owner -and $LabOut) {
            $labId2 = [string](Get-Prop $LabOut @('LAB_ID'))
            foreach ($r in @(@{ Key = 'url_platform'; Repo = "prel37-$labId2-platform" }, @{ Key = 'url_app'; Repo = "prel37-$labId2-app-deploy" })) {
                $u = Get-BlockOut $lb $r.Key
                $want = "github.com/$owner/$($r.Repo)"
                if ($u -and ($u -replace '\.git$', '') -like "*$want") { Add-Pass ('Repository ' + $r.Repo) ('origin is ' + $u) }
                else { Add-Fail ('Repository ' + $r.Repo) ("origin is '{0}', expected a remote at {1}" -f (Limit-Text $u 100), $want) }
            }
        }
        foreach ($b in @(@{ Key = 'branch_platform'; D = 'dirty_platform'; N = 'platform' }, @{ Key = 'branch_app'; D = 'dirty_app'; N = 'app-deploy' })) {
            $br = Get-BlockOut $lb $b.Key; $dirty = Get-BlockOut $lb $b.D
            Add-Info ('Clone ' + $b.N) ('branch {0}, {1} uncommitted change(s)' -f $br, $dirty)
        }
        $perm = Get-BlockOut $lb 'perms'
        if ($perm -and $perm -match '^600 600 700') { Add-Pass 'Credential permissions' 'Token files are 600 and the folder is 700.' }
        elseif ($perm) { Add-Warn 'Credential permissions' ("stat reports '{0}'; expected 600 600 700." -f $perm.Trim()) }

        if ((Get-BlockOut $lb 'gh_ok') -eq 'ok') { Add-Pass 'GitHub CLI sign-in' ('gh is signed in as ' + (Get-BlockOut $lb 'gh_user')) } else { Add-Fail 'GitHub CLI sign-in' 'gh auth status fails in WSL.' }

        $ctxs = Get-BlockOut $lb 'contexts'
        if ($ctxs -and $ctxs -match 'prel37-control' -and $ctxs -match 'prel37-workload') { Add-Pass 'kubeconfig contexts' 'prel37-control and prel37-workload exist.' } else { Add-Fail 'kubeconfig contexts' ('Expected prel37-control and prel37-workload. ' + (& $lFail 'contexts')) }
        if ((Get-BlockOut $lb 'provider') -eq 'True') { Add-Pass 'provider-opentofu' 'Healthy.' } else { Add-Fail 'provider-opentofu' ('Not Healthy. ' + (& $lFail 'provider')) }
        $fn = Get-BlockOut $lb 'functions'
        if ($fn) {
            $rows = @($fn -split "`n" | Where-Object { $_ })
            $healthy = @($rows | Where-Object { ($_ -split "`t")[1] -eq 'True' })
            if ($rows.Count -ge 3 -and $healthy.Count -eq $rows.Count) { Add-Pass 'Crossplane functions' ('{0} functions Healthy' -f $rows.Count) } else { Add-Fail 'Crossplane functions' ('{0} of {1} Healthy (expected three)' -f $healthy.Count, $rows.Count) }
        } else { Add-Fail 'Crossplane functions' ('None found. ' + (& $lFail 'functions')) }
        if ((Get-BlockOut $lb 'gateway') -eq 'True') { Add-Pass 'Shared Gateway (platform-gateway/tenants)' 'Programmed.' } else { Add-Fail 'Shared Gateway (platform-gateway/tenants)' ('Not Programmed. ' + (& $lFail 'gateway')) }
        foreach ($sec in @(@{ K = 'sec_git'; N = 'crossplane-system/module-git-credentials' }, @{ K = 'sec_platform'; N = 'argocd/repo-platform' }, @{ K = 'sec_app'; N = 'argocd/repo-app-deploy' }, @{ K = 'sec_cluster'; N = 'argocd/cluster-workload' }, @{ K = 'sec_token'; N = 'platform-system/github-token' })) {
            if ($null -ne (Get-BlockOut $lb $sec.K)) { Add-Pass ('Secret ' + $sec.N) 'Exists (make auth applied it).' } else { Add-Fail ('Secret ' + $sec.N) 'Missing. make auth has not completed.' }
        }
    }

    # Local services, as an attendee's browser would reach them.
    foreach ($svc in @(@{ Port = 3000; Name = 'Backstage frontend'; Need = $true; Cmd = 'make backstage' }, @{ Port = 7007; Name = 'Backstage backend'; Need = $true; Cmd = 'make backstage' }, @{ Port = 8443; Name = 'Argo CD tunnel'; Need = $true; Cmd = 'make argocd' }, @{ Port = 8080; Name = 'Application tunnel'; Need = $false; Cmd = 'make app' })) {
        $up = Test-TcpPort -HostName '127.0.0.1' -Port $svc.Port
        if ($up) { Add-Pass ('{0} on 127.0.0.1:{1}' -f $svc.Name, $svc.Port) 'Listening.' }
        elseif ($svc.Need) { Add-Fail ('{0} on 127.0.0.1:{1}' -f $svc.Name, $svc.Port) ('Not listening. Run {0} in its own WSL terminal, from ~/prel37/setup after sourcing ~/prel37/config/lab.env.' -f $svc.Cmd) }
        else { Add-Info ('{0} on 127.0.0.1:{1}' -f $svc.Name, $svc.Port) 'Not listening. That is expected until Module 3 step 6.' }
    }
}

# ---------------------------------------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------------------------------------

$counts = @{ PASS = 0; WARN = 0; FAIL = 0; INFO = 0; SKIP = 0 }
foreach ($r in $script:Results) { $counts[$r.Status]++ }
$elapsed = (Get-Date) - $script:Started
$verdict = 'READY'
if ($counts.FAIL -gt 0) { $verdict = 'NOT READY' }
elseif ($counts.WARN -gt 0) { $verdict = 'READY WITH WARNINGS' }
$partial = ''
if ($script:AzureSkipReason) { $partial = "Azure and Kubernetes were not checked ($($script:AzureSkipReason)), so this is not a full check." }

if ($Json) {
    $obj = [ordered]@{
        Computer = $env:COMPUTERNAME; Started = $script:Started.ToString('o'); Seconds = [int]$elapsed.TotalSeconds
        LabId = $(if ($LabOut) { [string](Get-Prop $LabOut @('LAB_ID')) } else { $null })
        Verdict = $verdict; Note = $partial; Counts = $counts; Results = $script:Results
    }
    $obj | ConvertTo-Json -Depth 5
} else {
    Write-Line ''
    Write-Line '== Summary ==' 'Cyan'
    Write-Line ('{0} passed, {1} warnings, {2} failed, {3} skipped, {4} info  ({5:N0} seconds)' -f $counts.PASS, $counts.WARN, $counts.FAIL, $counts.SKIP, $counts.INFO, $elapsed.TotalSeconds)
    $failed = @($script:Results | Where-Object { $_.Status -eq 'FAIL' })
    if ($failed.Count -gt 0) {
        Write-Line 'Failed checks:' 'Red'
        foreach ($f in $failed) { Write-Line ('  - {0}: {1}' -f $f.Name, $f.Detail) 'Red' }
    }
    $warned = @($script:Results | Where-Object { $_.Status -eq 'WARN' })
    if ($warned.Count -gt 0) {
        Write-Line 'Warnings:' 'Yellow'
        foreach ($w in $warned) { Write-Line ('  - {0}: {1}' -f $w.Name, $w.Detail) 'Yellow' }
    }
    $color = 'Green'
    if ($verdict -eq 'NOT READY') { $color = 'Red' } elseif ($verdict -ne 'READY') { $color = 'Yellow' }
    Write-Line ''
    Write-Line ('RESULT: ' + $verdict) $color
    if ($partial) { Write-Line $partial 'Yellow' }
}

if ($ReportPath) {
    try {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add('PREL37 lab readiness report')
        $lines.Add(('Computer: {0}   Started: {1}   Duration: {2:N0}s' -f $env:COMPUTERNAME, $script:Started.ToString('yyyy-MM-dd HH:mm:ss'), $elapsed.TotalSeconds))
        $lines.Add(('Result: {0}. {1} passed, {2} warnings, {3} failed, {4} skipped. {5}' -f $verdict, $counts.PASS, $counts.WARN, $counts.FAIL, $counts.SKIP, $partial))
        $current = ''
        foreach ($r in $script:Results) {
            if ($r.Section -ne $current) { $lines.Add(''); $lines.Add('== ' + $r.Section + ' =='); $current = $r.Section }
            $text = '[{0}] {1}' -f $r.Status, $r.Name
            if ($r.Detail) { $text += ' - ' + $r.Detail }
            $lines.Add($text)
        }
        [System.IO.File]::WriteAllLines($ReportPath, $lines.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
        if (-not $Json) { Write-Line ('Report written to ' + $ReportPath) 'Gray' }
    } catch {
        Write-Line ('Could not write the report: ' + $_.Exception.Message) 'Yellow'
    }
}

if ($counts.FAIL -gt 0) { exit 1 }
exit 0
