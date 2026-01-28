{
  description = "Moltbot local";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-moltbot.url = "github:moltbot/nix-moltbot";
  };

  outputs = { self, nixpkgs, home-manager, nix-moltbot }:
    let
      # REPLACE: aarch64-darwin (Apple Silicon), x86_64-darwin (Intel), or x86_64-linux
      system = "<system>";
      pkgs = import nixpkgs { inherit system; overlays = [ nix-moltbot.overlays.default ]; };
    in {
      # REPLACE: <user> with your username (run `whoami`)
      homeConfigurations."<user>" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nix-moltbot.homeManagerModules.moltbot
          {
            # Required for Home Manager standalone
            home.username = "<user>";
            # REPLACE: /Users/<user> on macOS or /home/<user> on Linux
            home.homeDirectory = "<homeDir>";
            home.stateVersion = "24.11";
            programs.home-manager.enable = true;

            programs.moltbot = {
              # REPLACE: path to your managed documents directory
              documents = ./documents;
              instances.default = {
                enable = true;
                providers.telegram = {
                  enable = true;
                  # REPLACE: path to your bot token file
                  botTokenFile = "<tokenPath>";
                  # REPLACE: your Telegram user ID (get from @userinfobot)
                  allowFrom = [ <allowFrom> ];
                  # Group defaults (required in Nix mode):
                  groups = {
                    "*" = { requireMention = true; };
                  };
                };
                providers.anthropic = {
                  # REPLACE: path to your Anthropic API key file
                  apiKeyFile = "<anthropicKeyPath>";
                };

                plugins = [
                  # Example plugin without config:
                  { source = "github:acme/hello-world"; }
                ];
              };
            };
          }
        ];
      };
    };
}
