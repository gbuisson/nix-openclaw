{ lib
, stdenvNoCC
, fetchzip
}:

stdenvNoCC.mkDerivation {
  pname = "moltbot-app";
  version = "2026.1.23";

  src = fetchzip {
    url = "https://github.com/moltbot/moltbot/releases/download/v2026.1.23/Clawdbot-2026.1.23.zip";
    hash = "sha256-HGN8yfDHkoP30YBk11U7kugE6RVkDs9oGwyUdLztToQ=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/moltbot-app-install.sh}";

  meta = with lib; {
    description = "Moltbot macOS app bundle";
    homepage = "https://github.com/moltbot/moltbot";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
