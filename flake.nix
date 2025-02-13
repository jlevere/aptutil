{
  description = "Build cybozu-go/aptutil make docker image for multi-arch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"] (
      system: let
        pkgs = import nixpkgs {inherit system;};

        go-apt-cacher = targetSystem: let
          arch =
            if targetSystem == "x86_64-linux"
            then "amd64"
            else "arm64";
        in
          pkgs.buildGoModule {
            name = "aptutil";
            src = self;
            subPackages = ["cmd/go-apt-cacher"];
            arch = arch;
            vendorHash = "sha256-cN3zTbVKf3cBdE1yAIwHWL61I0a6spwlawKTXQCWYJA=";
            env = {CGO_ENABLED = 0;};
          };

        docker-image = targetSystem: content: let
          arch =
            if targetSystem == "x86_64-linux"
            then "amd64"
            else "arm64";
        in
          pkgs.dockerTools.buildLayeredImage {
            name = "ghcr.io/jlevere/aptutil";
            tag = "latest-${arch}";
            contents = [
              pkgs.cacert
              content
            ];
            config = {
              Entrypoint = ["/bin/go-apt-cacher"];
              ExposedPorts = {"3142/tcp" = {};};
              Labels = {
                "org.opencontainers.image.architecture" = arch;
              };
            };
          };
      in {
        packages = rec {
          go-arm64 = go-apt-cacher "aarch64-linux";
          go-amd64 = go-apt-cacher "x86_64-linux";
          "arm64" = docker-image "aarch64-linux" go-arm64;
          "amd64" = docker-image "x86_64-linux" go-amd64;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [go gotools gopls];
        };

        apps.createManifest = {
          type = "app";
          program = pkgs.writeShellScript "create-manifest" ''
            #!/bin/sh
            ${pkgs.docker}/bin/docker manifest create ghcr.io/jlevere/aptutil:latest \
              --amend ghcr.io/jlevere/aptutil:latest-amd64 \
              --amend ghcr.io/jlevere/aptutil:latest-arm64

            ${pkgs.docker}/bin/docker manifest push ghcr.io/jlevere/aptutil:latest
          '';
        };
      }
    );
}
