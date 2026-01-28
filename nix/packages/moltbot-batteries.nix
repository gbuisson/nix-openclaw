{ lib
, buildEnv
, moltbot-gateway
, moltbot-app ? null
, extendedTools ? []
}:

let
  appPaths = lib.optional (moltbot-app != null) moltbot-app;
  appLinks = lib.optional (moltbot-app != null) "/Applications";
in
buildEnv {
  name = "moltbot-2.0.0-beta5";
  paths = [ moltbot-gateway ] ++ appPaths ++ extendedTools;
  pathsToLink = [ "/bin" ] ++ appLinks;

  meta = with lib; {
    description = "Moltbot batteries-included bundle (gateway + app + tools)";
    homepage = "https://github.com/moltbot/moltbot";
    license = licenses.mit;
    platforms = platforms.darwin ++ platforms.linux;
  };
}
