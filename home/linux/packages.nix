{pkgs, ...}: {
  home.packages = with pkgs; [
    gcc
    gnumake
    unzip
    curl
    
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
