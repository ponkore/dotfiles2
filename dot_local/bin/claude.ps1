#!/usr/bin/env pwsh
<#
  claude: 引数なしで起動した場合、どの CLAUDE_CONFIG_DIR で起動するかを
  fzf メニューで選択させる（矢印キー+Enter、または数字キーで即決定）。
  nyagos の claude エイリアスの移植。

  引数付きで実行した場合（例: claude --version）はメニューを出さず、
  環境変数を変更せずにそのまま実行する。
#>

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

# 再帰呼び出しを避けるため、実体の claude.exe (Application) をフルパスで解決する。
$claudeCmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $claudeCmd) {
    Write-Error "claude: 実行可能ファイルが見つかりません"
    exit 1
}
$claudePath = $claudeCmd.Source

$menuItems = @(
    [PSCustomObject]@{ Label = "1) 通常起動(Claude Pro)";      ConfigDir = $null }
    [PSCustomObject]@{ Label = "2) jighead(Claude Max)";        ConfigDir = Join-Path $env:USERPROFILE ".claude-config\jighead" }
    [PSCustomObject]@{ Label = "3) ESC-Web(Claude Enterprise)"; ConfigDir = Join-Path $env:USERPROFILE ".claude-config\ESC-Web" }
)

function Select-ClaudeMenu {
    $selection = $menuItems.Label | fzf --prompt="claude> " --height=~40% --border `
        --header="[Up/Down + Enter] or [1-3] で選択" `
        --bind="1:pos(1)+accept,2:pos(2)+accept,3:pos(3)+accept"

    if (-not $selection) {
        return $null
    }
    return $menuItems | Where-Object { $_.Label -eq $selection } | Select-Object -First 1
}

$skipMenu = ($Args.Count -eq 1) -and ($Args[0] -eq "--version" -or $Args[0] -eq "update")

if ($skipMenu) {
    & $claudePath @Args
    exit $LASTEXITCODE
}

$chosen = Select-ClaudeMenu
if (-not $chosen) {
    Write-Host "claude: キャンセルしました"
    exit 0
}

$prevConfigDir = $env:CLAUDE_CONFIG_DIR
try {
    if ($chosen.ConfigDir) {
        $env:CLAUDE_CONFIG_DIR = $chosen.ConfigDir
    }
    else {
        Remove-Item Env:\CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
    }

    & $claudePath @Args
    exit $LASTEXITCODE
}
finally {
    if ($null -ne $prevConfigDir) {
        $env:CLAUDE_CONFIG_DIR = $prevConfigDir
    }
    else {
        Remove-Item Env:\CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
    }
}
