param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$InPng,
    [Parameter(Mandatory = $true)][string]$OutTex
)
$ErrorActionPreference = 'Stop'

# 排查用：把 TEXCreator 窗体上所有下拉框/复选框的名字和当前值打出来，再把转换的报错原样吐出来。
# 只有在 png2tex.ps1 装了之后才需要它，比如官方 Mod Tools 更新后控件改名、
# 或者你想确认 pixelFormatComboBox 的 index 到底对应哪种压缩格式。
$B = [Reflection.BindingFlags]'Public,NonPublic,Instance'

$asm = [Reflection.Assembly]::LoadFrom((Resolve-Path $Exe).Path)
$ft = $asm.GetType('TEXCreator.MainForm1')
Write-Output ('form type: ' + $ft.FullName)

$form = $null
try {
    $form = [Activator]::CreateInstance($ft)
    Write-Output ('instance ok: ' + $form.GetType().Name)
} catch {
    Write-Output ('CTOR FAIL: ' + $_.Exception.GetType().Name + ' :: ' + $_.Exception.Message)
    if ($null -ne $_.Exception.InnerException) { Write-Output ('   inner: ' + $_.Exception.InnerException.Message) }
    exit 1
}

foreach ($f in $ft.GetFields($B)) {
    if ($f.Name -match 'combo|Combo|mip|Mip|format|Format|premul|Premul|check|Check|box') {
        $v = $f.GetValue($form)
        $txt = if ($null -eq $v) { 'null' } elseif ($v.Text) { $v.Text } else { $v.ToString() }
        $sel = if ($v.SelectedItem) { $v.SelectedItem.ToString() } else { '' }
        $idx = if ($null -ne $v.SelectedIndex) { $v.SelectedIndex } else { '' }
        Write-Output ('   field ' + $f.Name + ' [' + $f.FieldType.Name + '] text=' + $txt + ' selected=' + $sel + ' idx=' + $idx)
    }
}

try {
    $out = [IO.File]::Create($OutTex)
    $m = $ft.GetMethod('ConvertPNGToTex', $B)
    $m.Invoke($form, @($InPng, $out))
    $out.Close()
    Write-Output ('CONVERT OK -> ' + $OutTex + ' size=' + (Get-Item $OutTex).Length)
} catch {
    Write-Output ('CONVERT FAIL: ' + $_.Exception.GetType().Name + ' :: ' + $_.Exception.Message)
    if ($null -ne $_.Exception.InnerException) { Write-Output ('   inner: ' + $_.Exception.InnerException.GetType().Name + ' ' + $_.Exception.InnerException.Message) }
}
