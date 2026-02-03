{ pkgs
, sourceInfo ? import ../sources/openclaw-source.nix
, steipetePkgs ? {}
, toolNamesOverride ? null
, excludeToolNames ? []
}:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  toolSets = import ../tools/extended.nix {
    pkgs = pkgs;
    steipetePkgs = steipetePkgs;
    inherit toolNamesOverride excludeToolNames;
  };
  moltbotGateway = pkgs.callPackage ./openclaw-gateway.nix {
    inherit sourceInfo;
    pnpmDepsHash = sourceInfo.pnpmDepsHash or null;
  };
  moltbotApp = if isDarwin then pkgs.callPackage ./openclaw-app.nix { } else null;
  moltbotTools = pkgs.buildEnv {
    name = "moltbot-tools";
    paths = toolSets.tools;
    pathsToLink = [ "/bin" ];
  };
  moltbotBundle = pkgs.callPackage ./openclaw-batteries.nix {
    openclaw-gateway = moltbotGateway;
    openclaw-app = moltbotApp;
    extendedTools = toolSets.tools;
  };
in {
  openclaw-gateway = moltbotGateway;
  moltbot = moltbotBundle;
  moltbot-tools = moltbotTools;
} // (if isDarwin then { openclaw-app = moltbotApp; } else {})
