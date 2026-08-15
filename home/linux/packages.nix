{pkgs, ...}: {
  home.packages = with pkgs; [
    bandwhich
    gcc
    uv
    gnumake
    unzip
    curl
    glow
    # wslu removed 2026-08-15 — dropped from nixpkgs; upstream project is
    # discontinued and the repo archived. Nothing in this config or the shell
    # referenced it. If `wslview` is ever needed again, call
    # /mnt/c/Windows/explorer.exe directly, or use the wsl-open package.

    # Playwright browser automation dependencies
    nss
    nspr
    gtk3
    cups
    libdrm
    mesa
    libxcomposite
    libxdamage
    libxrandr
    alsa-lib
    dbus
    expat
    libxcb
    libxkbcommon
    glib
    pango
    cairo
    atk
    at-spi2-atk
    at-spi2-core
    libgbm
  ];
}
