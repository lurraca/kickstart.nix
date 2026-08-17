{lib, ...}: {
  # Personal git identity, on its own so headless hosts can take it without
  # the desktop side of personal.nix (Obsidian, tmuxinator layouts).
  # personal.nix imports this; so does home/kodama.nix.
  programs.git.settings.user = {
    email = lib.mkForce "me@lurraca.com";
    name = lib.mkForce "Luis Urraca";
  };
}
