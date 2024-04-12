{pkgs, ...}: {
  # add home-manager user settings here
  home.packages = with pkgs; [];
  home.stateVersion = "23.11";

