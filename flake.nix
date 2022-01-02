{
  description = "editor";
  outputs = { self, nixpkgs }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
    };
  in {
    devShell.x86_64-linux = pkgs.mkShell {
      name = "editor";
      buildInputs = with pkgs; [
        dmd
        dub
        SDL2
        SDL2_ttf
      ];
    };
  };
}
