# Tracks pi-coding-agent (https://pi.dev/) ahead of nixpkgs.
#
# nixpkgs' own `pi-coding-agent` package is stuck on 0.80.2: newer releases
# moved the LLM provider catalog from one committed models.generated.ts file
# into ~38 gitignored, build-time-generated data/*.json files fetched from
# OpenRouter/models.dev, so nixpkgs' sandboxed TypeScript source build can no
# longer produce them. Fixing that source build properly is real, ongoing
# nixpkgs packaging work, not something to redo on every version bump here.
#
# Workaround: skip the source build entirely. `npm install` the pre-built
# npm package inside a fixed-output derivation (network access is allowed for
# FODs because the result is content-hash-verified, same trust model as
# fetchurl), strip the `examples/` directory (the only files in the tarball
# whose shebangs get patched to a nix store bash path, which is illegal
# inside a FOD), then wrap `dist/cli.js` with node.
#
# Verified working end to end on 2026-07-31 (`pi --version` -> 0.83.0).
#
# To bump the version: change `version` below, set `outputHash` to
# `prev.lib.fakeHash`, run a build, copy the "got:" hash it reports back into
# `outputHash`, then rebuild and verify `pi --version`.
#
# Retire this file once nixpkgs' pi-coding-agent catches up past this
# workaround (check https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/pi/pi-coding-agent/package.nix).
final: prev: {
  pi-coding-agent = prev.stdenvNoCC.mkDerivation (let
    version = "0.83.0";
    npmInstall = prev.stdenvNoCC.mkDerivation {
      pname = "pi-coding-agent-npm-install";
      inherit version;
      nativeBuildInputs = [prev.nodejs_24 prev.cacert];
      dontUnpack = true;
      buildPhase = ''
        export HOME=$TMPDIR
        npm install --global --prefix=$out --no-audit --no-fund --ignore-scripts @earendil-works/pi-coding-agent@${version}
        rm -rf $out/bin $out/lib/node_modules/.bin
        rm -rf $out/lib/node_modules/@earendil-works/pi-coding-agent/examples
      '';
      dontInstall = true;
      outputHashMode = "recursive";
      outputHash = "sha256-OL/z/rEMUjtA/V16nxpwpX5AZk12gCcpVODkvIfg4Ro=";
    };
  in {
    pname = "pi-coding-agent";
    inherit version;
    dontUnpack = true;
    dontBuild = true;
    nativeBuildInputs = [prev.makeBinaryWrapper];
    installPhase = ''
      mkdir -p $out/lib $out/bin
      cp -r ${npmInstall}/lib/node_modules $out/lib/
      makeWrapper ${prev.nodejs_24}/bin/node $out/bin/pi \
        --prefix PATH : ${prev.lib.makeBinPath [prev.ripgrep prev.fd]} \
        --set-default PI_SKIP_VERSION_CHECK 1 \
        --set-default PI_TELEMETRY 0 \
        --add-flags "$out/lib/node_modules/@earendil-works/pi-coding-agent/dist/cli.js"
    '';
    meta = {
      description = "Coding agent CLI with read, bash, edit, write tools and session management (npm-tracked overlay, ahead of nixpkgs)";
      homepage = "https://pi.dev/";
      license = prev.lib.licenses.mit;
      mainProgram = "pi";
    };
  });
}
