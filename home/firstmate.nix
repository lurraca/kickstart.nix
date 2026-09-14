{
  pkgs,
  ...
}: {
  # Firstmate agent dispatch profiles. The live firstmate home reads
  # ~/code/firstmate/config/crew-dispatch.json; this module keeps that file
  # under version control here and links it in, so model-routing changes are
  # reviewed and committed like the rest of the setup.
  #
  # Contents are model routing only (no credentials: the gateway key is
  # referenced as $AI_GATEWAY_ACCESS_TOKEN by the consumer, never stored).
  # Firstmate treats this file as firstmate-maintained but human-editable, and
  # secondmate homes inherit it read-only, so edit it HERE from now on and run
  # darwin-rebuild switch; editing the linked file directly will be overwritten
  # by the next rebuild.
  #
  # Also carries the runtime backend pin (which session provider new workers
  # use). Both files are gitignored in the firstmate repo itself - they are
  # captain-local choices - which is exactly why they live here.
  home.file."code/firstmate/config/crew-dispatch.json".source = ./firstmate/crew-dispatch.json;

  home.file."code/firstmate/config/backend".text = ''
    cmux
  '';
}
