param(
    # Must be a directory with openvpn, openvpn-gui, vcpkg and
    # openvpn-build side by side
    [string] $basedir,
    # Version of OpenSSL port to use ("ossl1.1.1" or "ossl3")
    [string] $ossl = "ossl3",
    [string] $arch = "all",
    [switch] $nosign,
    [switch] $nodevprompt
    )

### Preparations
if(-not($basedir)) {
    Write-Host "Usage: build-and-package.ps1 -basedir <basedir> [-openssl] <ossl1.1.1|ossl3> [-arch] <all|x86|amd64|arm64> [-nosign] [-nodevprompt]"
    exit 1
}

$allowed_arch = "all", "x86", "amd64", "arm64"
if (-Not($allowed_arch.Contains($arch)))
{
    Write-Host "-arch must be:" $allowed_arch
    exit 1
}

# at the moment signing script doesn't support per-architecture signing
if (-Not($nosign) -And $arch -ne "all")
{
    Write-Host "-arch must be 'all' or omitted when -nosign is not specified"
    exit 1
}

# Convert relative path to absolute to prevent breakages below
$basedir = (Resolve-Path -Path $basedir)

$basedir_exists = Test-Path $basedir

if ($basedir_exists -ne $True) {
    Write-Host "ERROR: directory ${basedir} does not exist!"
    exit 1
}

if ((Test-Path "${PSScriptRoot}/build-and-package-env.ps1") -ne $True) {
    Write-Host "ERROR: configuration file (build-and-package-env.ps1) is missing"
    exit 1
}

. "${PSScriptRoot}/build-and-package-env.ps1"

# At the end of the build return to the directory we started from
$cwd = Get-Location

### Ensure that we use latest "contrib" vcpkg ports
Set-Location "${basedir}\openvpn"
& git.exe pull

Set-Location "${basedir}\vcpkg"
& git.exe pull
& .\bootstrap-vcpkg.bat
& .\vcpkg.exe integrate install

### Build OpenVPN-GUI
Set-Location "${basedir}\openvpn-gui"
& git.exe pull

$gui_arch = @()
switch ($arch)
{
    'all'
    {
        $gui_arch = "x64", "arm64", "x86"
    }
    'x86'
    {
        $gui_arch += "x86"
    }
    'amd64'
    {
        $gui_arch += "x64"
    }
    'arm64'
    {
        $gui_arch += "arm64"
    }
}

$gui_arch | ForEach-Object  {
	$platform = $_
    Write-Host "Building openvpn-gui ${platform}"
    # openvpn-gui presets are "<plat>" (configure) and "<plat>-release" (build); no "-ossl*" variant.
    & "$Env:CMAKE" -S . --preset ${platform}
    & "$Env:CMAKE" --build --preset ${platform}-release
}

### Stage openvpn-gui.exe where build.wsf expects it (out\build\<plat>-release-ossl3\)
$guiExe = Get-ChildItem "${basedir}\openvpn-gui\out" -Recurse -Filter "openvpn-gui.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($guiExe) {
    foreach ($p in @("x86-release-ossl3","x64-release-ossl3","arm64-release-ossl3")) {
        $d = "${basedir}\openvpn-gui\out\build\$p"
        New-Item -ItemType Directory -Force -Path $d | Out-Null
        Copy-Item $guiExe.FullName -Destination $d -Force
    }
    Write-Host "Staged openvpn-gui.exe from $($guiExe.FullName)"
} else {
    Write-Host "WARNING: openvpn-gui.exe not found under openvpn-gui\out"
}

### Build OpenVPN
Set-Location "${basedir}\openvpn"
& git.exe pull

if (($arch -eq "all") -Or ($arch -eq "amd64")) {
    if (-not($nodevprompt))
    {
        & "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
    }
    msbuild "openvpn.sln" /p:Configuration="Release" /p:Platform="x64" /maxcpucount /t:Build
}

if (($arch -eq "all") -Or ($arch -eq "x86")) {
    if (-not($nodevprompt))
    {
        & "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64_x86
    }
    msbuild "openvpn.sln" /p:Configuration="Release" /p:Platform="Win32" /maxcpucount /t:Build
}

if (($arch -eq "all") -Or ($arch -eq "arm64")) {
    if (-not($nodevprompt))
    {
        & "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64_arm64
    }
    msbuild "openvpn.sln" /p:Configuration="Release" /p:Platform="ARM64" /maxcpucount /t:Build
}

### Copy OpenSSL/vcpkg RELEASE runtime DLLs next to the built OpenVPN binaries (build.wsf packages from there).
### CRITICAL: source ONLY from the manifest-mode vcpkg_installed RELEASE bin and EXCLUDE any '\debug\' path.
### The debug variant of libpkcs11-helper-1.dll links the debug CRT (vcruntime140d.dll / ucrtbased.dll),
### which is NOT redistributable and absent on user machines -> openvpn.exe fails to load (STATUS_DLL_NOT_FOUND)
### -> mass service_start_error. Pulling release-only guarantees a dependency on the normal vcruntime140.dll.
Write-Host "=== Staging RELEASE vcpkg runtime DLLs (libcrypto-1_1/libssl-1_1/libpkcs11-helper, no debug) ==="
$found = Get-ChildItem "${basedir}\openvpn" -Recurse -Include "libcrypto-1_1*.dll","libssl-1_1*.dll","libpkcs11-helper-1.dll" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\vcpkg_installed\\' -and $_.FullName -notmatch '\\debug\\' }
$found | ForEach-Object { Write-Host ("  FOUND (release): " + $_.FullName) }
if (-not $found) { Write-Host "  WARNING: no release DLLs found under vcpkg_installed" }
foreach ($outRel in @("Win32-Output\Release","x64-Output\Release","ARM64-Output\Release")) {
    $out = Join-Path "${basedir}\openvpn" $outRel
    if (Test-Path $out) {
        $found | Copy-Item -Destination $out -Force -ErrorAction SilentlyContinue
        # перевірка: жодна стейджена DLL не має тягнути debug-CRT
        Get-ChildItem $out -Filter 'libpkcs11-helper-1.dll' -EA SilentlyContinue | ForEach-Object {
            $t = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($_.FullName))
            if ($t -match 'vcruntime140d\.dll|ucrtbased\.dll|msvcp140d\.dll') { Write-Host ("  !!! DEBUG-CRT dependency still in " + $_.FullName) }
        }
        Write-Host ("Staged into ${outRel}: " + ((Get-ChildItem $out -Filter '*.dll' -EA SilentlyContinue | Select-Object -Expand Name) -join ', '))
    }
}

### Sign binaries
if (-not $nosign) {
    Set-Location "${basedir}\openvpn-build\windows-msi"
    $Env:SignScript = "sign-openvpn.bat"
    & .\sign-binaries.bat
} else {
    Write-Host "Skip signing binaries"
}

### Build MSI
Set-Location "${basedir}\openvpn-build\windows-msi"

switch ($arch)
{
    'all'
    {
        & cscript.exe build.wsf msi
    }
    'amd64'
    {
        & cscript.exe build.wsf msi-amd64
    }
    'x86'
    {
        & cscript.exe build.wsf msi-x86
    }
    'arm64'
    {
        & cscript.exe build.wsf msi-arm64
    }
}

### Sign MSI
if (-not $nosign) {
    $Env:SignScript = "sign-msi.bat"
    & .\sign-binaries.bat
} else {
    Write-Host "Skip signing MSI"
}

Set-Location $cwd
