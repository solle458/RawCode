{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
        rust-overlay.url = "github:oxalica/rust-overlay";
        flake-utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
        flake-utils.lib.eachDefaultSystem (system:
            let
                pkgs = import nixpkgs {
                    inherit system;
                    overlays = [ rust-overlay.overlays.default ];
                };

                # Tauri/Linux向けの依存はLinuxでのみ有効化する
                libraries =
                    (with pkgs; pkgs.lib.optionals pkgs.stdenv.isLinux [
                        webkitgtk_4_1
                        gtk3
                        cairo
                        gdk-pixbuf
                        glib
                        dbus
                    ]);

                packages =
                    (with pkgs; [
                        curl
                        wget
                        pkg-config
                        openssl_3
                    ])
                    ++ (with pkgs; pkgs.lib.optionals pkgs.stdenv.isLinux [
                        libpcap
                        libnm
                    ]);
            in
            {
                devShells.default = pkgs.mkShell {
                    buildInputs = [
                        (pkgs.rust-bin.stable.latest.default.override{ extensions = [ "rust-src" "rust-analyzer" ]; })
                        pkgs.nodejs
                        pkgs.nodePackages.pnpm
                        pkgs.cargo-tauri
                    ] ++ libraries ++ packages;

                    # Tauriがライブラリを見つけるための環境変数設定（Linuxのみ）
                    shellHook =
                        pkgs.lib.optionalString pkgs.stdenv.isLinux ''
                            export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath libraries}:$LD_LIBRARY_PATH
                        ''
                        + ''
                            echo "Nix DevShell for Tauri Project Loaded!"
                        '';
                };
            }
        );
}