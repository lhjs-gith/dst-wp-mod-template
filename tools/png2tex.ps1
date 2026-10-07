param(
    [Parameter(Mandatory = $true)][string]$InPng,
    [Parameter(Mandatory = $true)][string]$OutTex,
    [string]$Exe = $env:TEXCREATOR_EXE,
    [bool]$Mipmaps = $true,
    [bool]$Premultiply = $true,
    [int]$TextureTypeIndex = 0,
    [int]$PixelFormatIndex = 2
)
$ErrorActionPreference = 'Stop'

# Klei 的 TEXCreator 没有命令行版本，只能反射调它的 WinForms 方法。
# 必须用 32 位 PowerShell 跑（64 位加载 KleiLib.dll 会 BadImageFormatException）：
#   C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe `
#     -NoProfile -ExecutionPolicy Bypass -File tools\png2tex.ps1 -InPng x.png -OutTex x.tex
# -Exe 指向 Steam 的 Don't Starve Mod Tools 里那个 TEXCreator.exe，也可以设环境变量 TEXCREATOR_EXE
if ([string]::IsNullOrEmpty($Exe)) {
    $Exe = 'C:\SteamLibrary\steamapps\common\Don''t Starve Mod Tools\mod_tools\TEXCreator.exe'
}
if (-not (Test-Path $Exe)) {
    Write-Output ('TEXCreator.exe not found: ' + $Exe)
    Write-Output 'Install the "Don''t Starve Mod Tools" Steam tool, then pass -ExE <path> (or set TEXCREATOR_EXE).'
    exit 2
}

$B = [Reflection.BindingFlags]'Public,NonPublic,Instance'
$asm = [Reflection.Assembly]::LoadFrom((Resolve-Path $Exe).Path)
$ft = $asm.GetType('TEXCreator.MainForm1')
$form = [Activator]::CreateInstance($ft)

function Set-C($name, $action) {
    $f = $ft.GetField($name, $B)
    if ($null -eq $f) { Write-Output ('   no field ' + $name); return }
    $ctrl = $f.GetValue($form)
    & $action $ctrl
    Write-Output ('   set ' + $name + ' -> ' + $(if ($ctrl.Checked) { 'checked=' + $ctrl.Checked } elseif ($ctrl.Text) { $ctrl.Text } else { '?' }))
}

# 下拉框必须先设好再转换：index 0 = textureType 1D（index 1 的 2D 会直接崩），index 2 = DXT5
Set-C 'generateMipmapsCheckBox' { param($c) $c.Checked = $Mipmaps }
Set-C 'preMultiplyAlphaCheckBox' { param($c) $c.Checked = $Premultiply }
Set-C 'textureTypeComboBox' { param($c) $c.SelectedIndex = $TextureTypeIndex }
Set-C 'pixelFormatComboBox' { param($c) $c.SelectedIndex = $PixelFormatIndex }
Set-C 'mipmapFilterComboBox' { param($c) $c.SelectedIndex = 0 }

$out = [IO.File]::Create($OutTex)
try {
    $ft.GetMethod('ConvertPNGToTex', $B).Invoke($form, @($InPng, $out))
} finally {
    $out.Close()
}
Write-Output ('WROTE ' + $OutTex + ' size=' + (Get-Item $OutTex).Length)

$log = $ft.GetField('logListBox', $B).GetValue($form)
foreach ($item in $log.Items) { Write-Output ('   log: ' + $item) }
