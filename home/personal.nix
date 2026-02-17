{lib, ...}: {
  programs.git.settings.user = {
    email = lib.mkForce "lurraca@gmail.com";
    name = lib.mkForce "Luis Urraca";
  };
}
