dnl ============================================================
dnl Downloadables
dnl ============================================================

dnl TAP-Windows binaries
define([PRODUCT_TAP_WIN_URL_x86],      [https://build.openvpn.net/downloads/releases/tap-windows-9.24.6-I601-i386.msm])
define([PRODUCT_TAP_WIN_URL_amd64],    [https://build.openvpn.net/downloads/releases/tap-windows-9.24.6-I601-amd64.msm])
define([PRODUCT_TAP_WIN_URL_arm64],    [https://build.openvpn.net/downloads/releases/tap-windows-9.24.6-I601-arm64.msm])
define([PRODUCT_TAP_WIN_COMPONENT_ID], [tap0901])
define([PRODUCT_TAP_WIN_NAME],         [TAP-Windows])

dnl Wintun binaries
define([PRODUCT_WINTUN_URL_x86],       [https://www.wintun.net/builds/wintun-x86-0.8.1.msm])
define([PRODUCT_WINTUN_URL_amd64],     [https://www.wintun.net/builds/wintun-amd64-0.8.1.msm])
dnl This is only to make build script happy - the file is only downloaded but not used, since there is no arm64 wintun MSM (yet)
define([PRODUCT_WINTUN_URL_arm64],     [https://www.wintun.net/builds/wintun-amd64-0.8.1.msm])

dnl OpenVPNServ2.exe binary
define([OPENVPNSERV2_URL], [http://build.openvpn.net/downloads/releases/openvpnserv2-1.4.0.1.exe])

dnl Easy RSA binaries (URL to .tar.gz file containing "easy-rsa-[EASYRSA_VERSION]" folder with Easy RSA)
define([EASYRSA_VERSION], [3.1.0])
define([EASYRSA_URL],     [https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.0/EasyRSA-3.1.0-win64.zip])


dnl ============================================================
dnl MSI Provisioning
dnl ============================================================

dnl Define the product name and publisher.
dnl FastOrange: PRODUCT_NAME керує реєстром (Software\FastOrange), папкою, ARP (Uninstall\FastOrange),
dnl NSIS-детектом і назвами адаптерів — каскадна ізоляція від нативного OpenVPN (він шукає "OpenVPN").
define([PRODUCT_NAME],      [FastOrange])
define([PRODUCT_PUBLISHER], [FastOrange])

dnl The package version as displayed by UI and used in filenames (no spaces, please).
dnl Має відповідати реальному openvpn (workflow чекаутить v2.5.7) — це лише лейбл у назві файлу/ProductName.
define([PACKAGE_VERSION], [2.5.7])

dnl The MSI product version in the form of n[.n[.n]] (numbers only).
dnl The third field is 100*product release + package version.
dnl The fourth field is ignored by MSI.
define([PRODUCT_VERSION], [2.5.028])

dnl The MSI product code MUST change on each product release.
define([PRODUCT_CODE], [{B562EDDC-71C2-4B1F-A0FC-0A7DFF760B3C}])

dnl The MSI upgrade codes MUST persist for all versions of the same product line.
dnl FastOrange: ВЛАСНІ upgrade-коди (не офіційні OpenVPN) — щоб наш продукт був окремою лінією.
define([UPGRADE_CODE_x86],   [{D4A37A47-89CA-4B84-9B6C-2CAA0DC6210C}])
define([UPGRADE_CODE_amd64], [{88BE1124-5BBA-4040-B3AF-A09E38660D54}])
define([UPGRADE_CODE_arm64], [{CB06870B-148E-483E-AE27-5071F8139215}])

dnl OpenVPN configration file extension (e.g. conf, ovpn...)
define([CONFIG_EXTENSION], [ovpn])
