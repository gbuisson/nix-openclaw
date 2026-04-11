{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.4.11-beta.1";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.4.11-beta.1/OpenClaw-2026.4.11-beta.1.zip";
    hash = "sha256-oVqwd1SfN2wrBFZK81PY+Vro4/AUItq3M2UddsZKAl0=";
    stripRoot = false;
  };

  dontUnpack = true;

  installPhase = "${../scripts/openclaw-app-install.sh}";

  meta = with lib; {
    description = "OpenClaw macOS app bundle";
    homepage = "https://github.com/openclaw/openclaw";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
