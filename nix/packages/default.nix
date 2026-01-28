{ pkgs
, sourceInfo ? import ../sources/moltbot-source.nix
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
  moltbotGateway = pkgs.callPackage ./moltbot-gateway.nix {
    inherit sourceInfo;
    pnpmDepsHash = sourceInfo.pnpmDepsHash or null;
  };
  moltbotApp = if isDarwin then pkgs.callPackage ./moltbot-app.nix { } else null;
  moltbotTools = pkgs.buildEnv {
    name = "moltbot-tools";
    paths = toolSets.tools;
    pathsToLink = [ "/bin" ];
  };
  moltbotBundle = pkgs.callPackage ./moltbot-batteries.nix {
    moltbot-gateway = moltbotGateway;
    moltbot-app = moltbotApp;
    extendedTools = toolSets.tools;
  };
in {
  moltbot-gateway = moltbotGateway;
  moltbot = moltbotBundle;
  moltbot-tools = moltbotTools;
} // (if isDarwin then { moltbot-app = moltbotApp; } else {})
