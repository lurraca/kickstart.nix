{pkgs, ...}: {
  home.packages = with pkgs; [
    gcc
    gnumake
    unzip
    curl
  ];
}
