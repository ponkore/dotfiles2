# Claude Code の通知を Windows のトーストとして表示する。
# AUMID に WezTerm のものを使うため、通知は「WezTerm」からのものとして扱われる
# (設定 > システム > 通知 の WezTerm の項目で ON/OFF できる)。
#
# WinRT の API を使うので Windows PowerShell 5.1 (powershell.exe) で実行すること。
# pwsh 7 では動かない。
param(
  [Parameter(Mandatory = $true)][string]$Title,
  [Parameter(Mandatory = $true)][string]$Body
)

$ErrorActionPreference = 'Stop'

[void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
[void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]

function Esc([string]$s) {
  $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
}

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml(
  '<toast><visual><binding template="ToastGeneric">' +
  '<text>' + (Esc $Title) + '</text>' +
  '<text>' + (Esc $Body) + '</text>' +
  '</binding></visual></toast>'
)

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('org.wezfurlong.wezterm').Show($toast)
