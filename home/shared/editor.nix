{pkgs, ...}: {
  # nvim is installed as a plain package so home-manager does NOT manage
  # ~/.config/nvim/init.lua — that directory is our own kickstart.nvim git repo.
  home.packages = [pkgs.neovim];
}
