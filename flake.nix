{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        rust-overlay.url = "github:oxalica/rust-overlay";
    };

    outputs = { self, nixpkgs, rust-overlay, ... }:
        let
            pkgs = import nixpkgs { 
                overlays = [ rust-overlay.overlays.default ]; 
            };
            # Tauri
            libraries = with pkgs; [ webkitgtk_4_1 gtk3 cairo gdk-pixbuf glib dbus openssl_3 ];
            packages = with pkgs; [
                curl wget pkg-config dbus-lexicon
                libpcap libnm
            ];
        in {
            devShells.default = pkgs.mkShell {
                buildInputs = [
                    (rust-bin.stable.latest.default.override{ extensions = [ "rust-src" "rust-analyzer" ]; })
                    nodejs_22
                    nodePackages.pnpm
                    cargo-tauri
                ] ++ libraries ++ packages;

                # Tauriがライブラリを見つけるための環境変数設定
                shellHook = ''
                    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraries}:$LD_LIBRARY_PATH
                    echo "🚀 Nix DevShell for Tauri Project Loaded!"
                '';
            };
        };
}