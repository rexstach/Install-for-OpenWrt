# Install-for-OpenWrt
This combined shell script installs the following packages: Wireguard, Podkop, Sing-box.
First, Wireguard is installed with pre‑configured settings to enable remote access to the OpenWrt router. Then Sing-box is installed, with the option to choose a version, followed by Podkop.
### Usage:
```sh
curl -fsSL https://raw.githubusercontent.com/rexstach/Install-for-OpenWrt/refs/heads/main/install.sh | sh
```
### Specific version sing-box
```sh
curl -fsSL https://raw.githubusercontent.com/rexstach/Install-for-OpenWrt/refs/heads/main/install.sh | sh -s -- --version <version>
```
