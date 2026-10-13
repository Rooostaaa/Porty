param([string]$Name)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices; using System.Text;
public class CapW {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct PT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref PT p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  public static IntPtr Find(string part) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, p) => { if (!IsWindowVisible(h)) return true; var sb = new StringBuilder(256); GetWindowText(h, sb, 256);
      if (sb.ToString().Contains(part)) { found = h; return false; } return true; }, IntPtr.Zero);
    return found;
  }
}
"@
[CapW]::SetProcessDPIAware() | Out-Null
$h = [CapW]::Find("Idle Supermarket Tycoon")
if ($h -eq [IntPtr]::Zero) { throw "fenetre introuvable" }
$wr = New-Object CapW+RECT; [CapW]::GetWindowRect($h, [ref]$wr) | Out-Null
$cr = New-Object CapW+RECT; [CapW]::GetClientRect($h, [ref]$cr) | Out-Null
$pt = New-Object CapW+PT; [CapW]::ClientToScreen($h, [ref]$pt) | Out-Null
$ww = $wr.R - $wr.L; $wh = $wr.B - $wr.T
$full = New-Object System.Drawing.Bitmap $ww, $wh
$g = [System.Drawing.Graphics]::FromImage($full)
$hdc = $g.GetHdc(); [CapW]::PrintWindow($h, $hdc, 2) | Out-Null; $g.ReleaseHdc($hdc); $g.Dispose()
# recadre sur la zone client (sans bordure ni barre de titre)
$ox = $pt.X - $wr.L; $oy = $pt.Y - $wr.T; $cw = $cr.R; $ch = $cr.B
$crop = $full.Clone((New-Object System.Drawing.Rectangle $ox, $oy, $cw, $ch), $full.PixelFormat)
# plein écran : retire les bandes noires latérales
$y = [int]($ch / 2); $x0 = 0; $x1 = $cw - 1
while ($x0 -lt $x1 -and $crop.GetPixel($x0, $y).GetBrightness() -lt 0.02) { $x0++ }
while ($x1 -gt $x0 -and $crop.GetPixel($x1, $y).GetBrightness() -lt 0.02) { $x1-- }
if ($x0 -gt 4 -or $x1 -lt $cw - 5) { $cw = $x1 - $x0 + 1; $crop = $crop.Clone((New-Object System.Drawing.Rectangle $x0, 0, $cw, $ch), $crop.PixelFormat) }
$dir = "C:\Nadir\tycoon\docs\references\ism"
New-Item -ItemType Directory -Force $dir | Out-Null
$out = Join-Path $dir "$Name.png"
$crop.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
"$out ${cw}x${ch}"
