{
  description = "Amazon CloudWatch Agent for NixOS";

  inputs.nixpkgs.url = "nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      nixosModules.default = import ./module.nix self;

      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          amazon-cloudwatch-agent = pkgs.callPackage ./package.nix {};
        });

      defaultPackage = forAllSystems (system: self.packages.${system}.amazon-cloudwatch-agent);

      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [ go gopls gotools go-tools ];
          };
        });

    };
}
