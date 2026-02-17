{pkgs, ...}: {
  home.packages = with pkgs; [
    alejandra
    lua5_1
    lua51Packages.luarocks
    nodejs_24
    nil
    rustup
    tenv
    tig
    unixtools.watch
    wget
  ];

  programs.bat = {
    enable = true;
    config = {
      theme = "1337";
    };
  };

  programs.bottom = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.eza = {
    enable = true;
  };

  programs.hstr = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.jq = {
    enable = true;
  };

  programs.ripgrep = {
    enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    options = [
      "--hook pwd"
    ];
  };
}
