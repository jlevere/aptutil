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

        go-apt-cacher = pkgs.buildGoModule {
          name = "aptutil";
          src = self;
          vendorHash = "sha256-cN3zTbVKf3cBdE1yAIwHWL61I0a6spwlawKTXQCWYJA=";

          nativeBuildInputs = [pkgs.git];
          subPackages = ["cmd/go-apt-cacher"]; # Only build the apt-cache part
        };

        docker = pkgs.dockerTools.buildLayeredImage {
          name = "aptutil-docker";
          tag = "latest";
          contents = [go-apt-cacher];
          config = {
            Entrypoint = ["/go-apt-cacher"];
            ExposedPorts = {"3142/tcp" = {};};
          };
        };
      in {
        packages = {
          go-apt-cacher = go-apt-cacher;
          docker = docker;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [go gotools gopls];
        };
      }
    );
}
