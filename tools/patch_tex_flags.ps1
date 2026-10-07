param(
    [Parameter(Mandatory = $true)][string]$Tex,
    [byte]$Value = 0xFD
)
$ErrorActionPreference = 'Stop'

# TEXCreator 写出来的贴图头里第 6 字节（Flags）是 0，游戏实际能加载的那批贴图这里是 0xFD。
# 不补这一个字节的直接后果是游戏把贴图当无效、接缝垫图不出现（不报错，只是不显示）。
# png2tex.ps1 转完之后对每个 .tex 跑一次：
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\patch_tex_flags.ps1 -Tex images\1.tex
$fs = [IO.File]::Open($Tex, 'Open', 'ReadWrite', 'None')
try {
    if ($fs.Length -lt 8) { throw ('not a KTEX file: ' + $Tex) }
    $head = New-Object byte[] 4
    $fs.Read($head, 0, 4) | Out-Null
    if ([Text.Encoding]::ASCII.GetString($head) -ne 'KTEX') { throw ('magic is not KTEX: ' + $Tex) }
    $fs.Position = 6
    $old = $fs.ReadByte()
    $fs.Position = 6
    $fs.WriteByte($Value)
    Write-Output ('PATCHED ' + $Tex + ' byte6 0x' + ('{0:X2}' -f $old) + ' -> 0x' + ('{0:X2}' -f $Value))
} finally {
    $fs.Close()
}
