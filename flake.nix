{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sf-pro = {
      url = "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg";
      flake = false;
    };
  };

  outputs =
    inputs@{self, ...}:
    let
      systems = [
        "x86_64-darwin"
        "x86_64-linux"
      ];
      forEachSystem = inputs.nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};

          unpackPhase = pkgName: ''
            runHook preUnpack
            undmg $src
            7z x '${pkgName}'
            7z x 'Payload~'
            runHook postUnpack
          '';

          commonInstall = ''
            mkdir -p "$out/share/fonts"
            mkdir -p "$out/share/fonts/opentype"
            mkdir -p "$out/share/fonts/truetype"
          '';

          commonBuildInputs = builtins.attrValues { inherit (pkgs) undmg p7zip; };

          makeAppleFont = (
            name: pkgName: src:
            pkgs.stdenvNoCC.mkDerivation {
              inherit name src;

              unpackPhase = unpackPhase pkgName;

              buildInputs = commonBuildInputs;
              setSourceRoot = "sourceRoot=`pwd`";

              installPhase =
                ''runHook preInstall''
                + commonInstall
                + ''
                  find -name \*.otf -exec mv {} "$out/share/fonts/opentype/" \;
                  find -name \*.ttf -exec mv {} "$out/share/fonts/truetype/" \;
                ''
                + ''runHook preInstall'';
            }
          );

          makeNerdAppleFont = (
            name: pkgName: src:
            pkgs.stdenvNoCC.mkDerivation {
              inherit name src;

              unpackPhase = unpackPhase pkgName;

              buildInputs =
                commonBuildInputs
                ++ builtins.attrValues { inherit (pkgs) parallel nerd-font-patcher; };

              setSourceRoot = "sourceRoot=`pwd`";

              buildPhase = ''
                runHook preBuild
                find -name \*.ttf -o -name \*.otf -print0 | parallel --will-cite -j $NIX_BUILD_CORES -0 nerd-font-patcher --no-progressbars -c {}
                runHook postBuild
              '';

              installPhase =
                ''runHook preInstall''
                + commonInstall
                + ''
                  find -name \*.otf -maxdepth 1 -exec mv {} "$out/share/fonts/opentype/" \;
                  find -name \*.ttf -maxdepth 1 -exec mv {} "$out/share/fonts/truetype/" \;
                ''
                + ''runHook preInstall'';
            }
          );
        in
        {
          sf-pro = makeAppleFont "sf-pro" "SF Pro Fonts.pkg" inputs.sf-pro;
          sf-pro-nerd = makeNerdAppleFont "sf-pro-nerd" "SF Pro Fonts.pkg" inputs.sf-pro;
        }
      );
      hydraJobs = {
        inherit (self) packages;
      };
    };
}
