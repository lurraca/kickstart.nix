{...}: {
  # SSH client entries for reaching the homelab from the work Mac, so herdr on
  # this machine can hold kodama and tokoyo as machines. Added 14 Sep 2026.
  #
  # LAN ONLY, by decision: no Tailscale on the work Mac. So no tailnet IPs and
  # no MagicDNS names here, and none of this works away from home.
  #
  # Written as a separate file rather than `programs.ssh`, because that would
  # take over ~/.ssh/config, which on a work machine already carries work hosts
  # this repo does not manage. Needs one line at the very top of ~/.ssh/config:
  #   Include config.d/homelab
  # herdr's own generated ssh config includes ~/.ssh/config first, so this chain
  # reaches `herdr machine` as well as plain ssh.
  #
  # ⚠️ The key below is effectively a shell on tokoyo and kodama. tokoyo hosts
  # robotina (health records, the analysis about leaving this employer), which
  # the repo's own rule keeps off this machine. The key has a passphrase held in
  # the macOS Keychain, and is revocable per machine by deleting one line.
  home.file.".ssh/config.d/homelab".text = ''
    # UseKeychain is Apple-OpenSSH only; a nixpkgs ssh would reject it outright.
    IgnoreUnknown UseKeychain

    Host kodama
      HostName 192.168.1.111
      User kasasagi
      IdentityFile ~/.ssh/id_ed25519_homelab
      IdentitiesOnly yes
      AddKeysToAgent yes
      UseKeychain yes
      ForwardAgent no

    # TEMPORARY address: tokoyo is still on DHCP. The planned reservation is
    # 192.168.1.121 (address plan in robotina notes/homelab/inventory.md).
    Host tokoyo
      HostName 192.168.1.4
      User kasasagi
      IdentityFile ~/.ssh/id_ed25519_homelab
      IdentitiesOnly yes
      AddKeysToAgent yes
      UseKeychain yes
      ForwardAgent no

    # Relies on router DHCP DNS (search domain 'station') instead of a pinned
    # IP — deliberate, for now. Add a reservation + HostName if it ever flakes.
    Host tanuki
      HostName tanuki.station
      User kasasagi
      IdentityFile ~/.ssh/id_ed25519_homelab
      IdentitiesOnly yes
      AddKeysToAgent yes
      UseKeychain yes
      ForwardAgent no
  '';
}
