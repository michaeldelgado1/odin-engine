{
  description = "Go Engine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = inputs:
    let
      goVersion = 24;
      supportedSystems = [ "x86_64-linux" ];
      forEachSupportedSystem = f: inputs.nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ inputs.self.overlays.default ];
        };
      });
    in
    {
      overlays.default = final: prev: {
        go = final."go_1_${toString goVersion}";
      };

      devShells = forEachSupportedSystem ({ pkgs }: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            odin
            # go (version is specified by overlay)
            # go

            # goimports, godoc, etc.
            # gotools

            # https://github.com/golangci/golangci-lint
            # golangci-lint

            # Linux specific Libs
            xorg.libX11
            xorg.libX11.dev
            xorg.libX11.dev.out
            xorg.libXcursor
            xorg.libXrandr
            xorg.libXinerama
            xorg.libXi
            libxkbcommon
            libGL
            # NOTE: This is a dumb hack because Odin and Nix are not working together
            raylib
            # NOTE: These didn't work, the sound is still broken
            # alsa-lib
            # libpulseaudio
          ];
        };
      });
    };
}
