#!/usr/bin/env pwsh
<#
  ya: yazi を起動し、終了後にカレントディレクトリを yazi 内で移動した
      ディレクトリに同期する（nyagos の ya エイリアスの移植）。
#>

$tmp = [System.IO.Path]::GetTempFileName()
try {
    yazi --cwd-file="$tmp"

    if (Test-Path -LiteralPath $tmp) {
        $cwd = Get-Content -LiteralPath $tmp -TotalCount 1 -ErrorAction SilentlyContinue
        if ($cwd -and $cwd -ne (Get-Location).Path) {
            Set-Location -LiteralPath $cwd
        }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
}
