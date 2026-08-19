#!/usr/bin/env pwsh
<#
.SYNOPSIS
  wezterm のワークスペースを fzf で選び、その作業レイアウトを一発で構築する。

.DESCRIPTION
  esc-web.ps1 を複数環境対応にしたもの。環境定義は $Environments に列挙する。

  - 対象ワークスペースが既に存在する場合はそのワークスペースへ移動するだけ。
  - 存在しない場合はワークスペースを新規ウィンドウとして作成し、
    その中に以下のレイアウトを構築してから移動する。
      - 上下に分割（サイズ比 上:下 = 1:2）
      - タブタイトルを環境ごとの Title に設定
      - 上ペイン: 作業ディレクトリで yazi を起動（終了すると nyagos に戻る）
      - 下ペイン: 作業ディレクトリで nyagos を起動（フォーカスもこちら）

  ワークスペースの切り替えは wezterm cli に該当サブコマンドが無いため、
  OSC 1337 SetUserVar でユーザー変数 switch_workspace を設定し、
  wezterm 側 (~/.config/wezterm/workspace.lua) のイベントハンドラに行わせる。

.EXAMPLE
  ws
  fzf メニューで ESC_Web / RINSETSU / config を選ぶ。

.EXAMPLE
  ws RINSETSU
  メニューを出さずに RINSETSU を開く。

.EXAMPLE
  ws ESC_Web -Title 'ESC(sub)' -Workspace ESC_Sub -FocusTop
#>
[CmdletBinding()]
param(
    # 環境名 (ESC_Web / RINSETSU / config)。省略時は fzf で選択する
    [Parameter(Position = 0)]
    [string]$Name,

    # 以下は環境定義の値を上書きしたいときだけ指定する
    [string]$Dir,
    [string]$Workspace,
    [string]$Title,

    # 下ペインが占める割合(%)。66 で 上:下 = 1:2
    [ValidateRange(1, 99)]
    [int]$BottomPercent,

    # 分割後に上(yazi)ペインへフォーカスする。既定は下(nyagos)ペイン
    [switch]$FocusTop
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- 環境定義 --
$Environments = @(
    [PSCustomObject]@{
        Name          = 'ESC_Web'
        Workspace     = 'ESC_Web'
        Dir           = 'C:/Projects/ESC-Web/WebCoreSystem_v1'
        Title         = 'ESC(main)'
        BottomPercent = 66
    }
    [PSCustomObject]@{
        Name          = 'RINSETSU'
        Workspace     = 'RINSETSU'
        Dir           = 'C:/Projects/nel/RINSETSU'
        Title         = 'RINSETSU'
        BottomPercent = 66
    }
    [PSCustomObject]@{
        Name          = 'config'
        Workspace     = 'config'
        Dir           = "$env:USERPROFILE/.config"
        Title         = 'config'
        BottomPercent = 66
    }
)

if (-not $env:WEZTERM_PANE) {
    throw 'wezterm のペイン内で実行してください (WEZTERM_PANE が未設定です)。'
}

function Resolve-Exe([string]$ExeName) {
    $cmd = Get-Command $ExeName -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $cmd) { throw "$ExeName が PATH 上に見つかりません。" }
    $cmd.Source
}

function Invoke-Wezterm([string[]]$WeztermArgs) {
    $out = & $script:Wezterm @WeztermArgs
    if ($LASTEXITCODE -ne 0) {
        throw ("wezterm {0} に失敗しました (exit {1})" -f ($WeztermArgs -join ' '), $LASTEXITCODE)
    }
    $out
}

# ワークスペースが存在するか (= そのワークスペースに属するペインが 1 つでもあるか)
#
# `--format json` はペインタイトルの文字化けで ConvertFrom-Json が失敗しうるため、
# 既定のテーブル出力の先頭 4 列 (WINID TABID PANEID WORKSPACE) だけを見る。
function Test-Workspace([string]$WorkspaceName) {
    foreach ($line in @(Invoke-Wezterm @('cli', 'list'))) {
        if ($line -match '^\s*\d+\s+\d+\s+\d+\s+(\S+)\s') {
            if ($Matches[1] -eq $WorkspaceName) { return $true }
        }
    }
    $false
}

# 指定ペインの行数 (list の SIZE 列 COLSxROWS)
function Get-PaneRows([string]$PaneId) {
    $pattern = '^\s*\d+\s+\d+\s+' + [regex]::Escape($PaneId) + '\s+\S+\s+\d+x(\d+)\s'
    foreach ($line in @(Invoke-Wezterm @('cli', 'list'))) {
        if ($line -match $pattern) { return [int]$Matches[1] }
    }
    0
}

# OSC 1337 SetUserVar でワークスペース切り替えを wezterm 本体に依頼する
function Switch-Workspace([string]$WorkspaceName) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($WorkspaceName))
    [Console]::Out.Write("$([char]27)]1337;SetUserVar=switch_workspace=$b64$([char]7)")
    [Console]::Out.Flush()
}

# fzf で環境を選ばせる (矢印キー+Enter、または数字キーで即決定)
function Select-Environment {
    if (-not (Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'fzf が PATH 上に見つかりません。環境名を引数で指定してください。'
    }

    $labels = @()
    $binds  = @()
    for ($i = 0; $i -lt $Environments.Count; $i++) {
        $n = $i + 1
        $labels += "$n) $($Environments[$i].Name)"
        $binds  += "${n}:pos(${n})+accept"
    }

    $headerArg = "--header=[Up/Down + Enter] or [1-$($Environments.Count)] で選択"
    $bindArg   = '--bind=' + ($binds -join ',')
    $selection = $labels | fzf --prompt="workspace> " --height=~40% --border $headerArg $bindArg

    if (-not $selection) { return $null }
    if ($selection -notmatch '^(\d+)\)') { return $null }
    $Environments[[int]$Matches[1] - 1]
}

# ---------------------------------------------------------------- 環境選択 --
if ($Name) {
    $envDef = $Environments | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $envDef) {
        throw ("不明な環境名です: {0} (有効: {1})" -f $Name, (($Environments.Name) -join ', '))
    }
}
else {
    $envDef = Select-Environment
    if (-not $envDef) {
        Write-Host 'ws: キャンセルしました'
        return
    }
}

# パラメータで明示指定されたものだけ環境定義を上書きする
$targetDir       = if ($PSBoundParameters.ContainsKey('Dir'))           { $Dir }           else { $envDef.Dir }
$targetWorkspace = if ($PSBoundParameters.ContainsKey('Workspace'))     { $Workspace }     else { $envDef.Workspace }
$targetTitle     = if ($PSBoundParameters.ContainsKey('Title'))         { $Title }         else { $envDef.Title }
$targetBottom    = if ($PSBoundParameters.ContainsKey('BottomPercent')) { $BottomPercent } else { $envDef.BottomPercent }

$script:Wezterm = Resolve-Exe 'wezterm'

# 1. 既にワークスペースがあるなら移動するだけ
if (Test-Workspace $targetWorkspace) {
    Write-Verbose "workspace '$targetWorkspace' は既に存在します。移動のみ行います。"
    Switch-Workspace $targetWorkspace
    return
}

# 2. 無い場合はレイアウトを構築する
if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
    throw "作業ディレクトリが見つかりません: $targetDir"
}

$nyagos = Resolve-Exe 'nyagos'
$yazi   = Resolve-Exe 'yazi'

# wezterm cli spawn/split-pane の --cwd は実際には効かず、新しいペインの
# 作業ディレクトリは wezterm cli 実行時の環境変数 PWD から決まる。
$dirFull = (Resolve-Path -LiteralPath $targetDir).ProviderPath
$prevPwd = $env:PWD
$env:PWD = $dirFull
try {
    # 上ペイン: nyagos 上で yazi を起動する (yazi 終了後は $targetDir のまま nyagos に戻る)
    $yaziCmd = if ($yazi -match '\s') { '"{0}"' -f $yazi } else { $yazi }
    $topPane = (Invoke-Wezterm @('cli', 'spawn', '--new-window', '--workspace', $targetWorkspace,
                                 '--cwd', $dirFull, '--', $nyagos, '--cmd-first', $yaziCmd) |
                Select-Object -First 1)
    Write-Verbose "top pane id: $topPane"

    # タブタイトル
    Invoke-Wezterm @('cli', 'set-tab-title', '--pane-id', $topPane, $targetTitle) | Out-Null

    # 分割前にワークスペースへ移動する。
    # 新規ウィンドウは GUI に載るまで既定サイズ(80x24)のままで、
    # その状態で分割すると後のリサイズで 1:2 の比率が崩れてしまうため。
    $rowsBefore = Get-PaneRows $topPane
    Switch-Workspace $targetWorkspace
    $deadline = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 100
        if ((Get-PaneRows $topPane) -ne $rowsBefore) { break }
    }

    # 下ペイン(2/3)を作り nyagos を起動
    $bottomPane = (Invoke-Wezterm @('cli', 'split-pane', '--pane-id', $topPane, '--bottom',
                                    '--percent', "$targetBottom", '--cwd', $dirFull,
                                    '--', $nyagos) |
                   Select-Object -First 1)
    Write-Verbose "bottom pane id: $bottomPane"

    # フォーカス
    $focusPane = if ($FocusTop) { $topPane } else { $bottomPane }
    Invoke-Wezterm @('cli', 'activate-pane', '--pane-id', $focusPane) | Out-Null
}
finally {
    if ($null -eq $prevPwd) { Remove-Item Env:PWD -ErrorAction SilentlyContinue }
    else { $env:PWD = $prevPwd }
}
