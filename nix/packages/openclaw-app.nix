{
  lib,
  stdenvNoCC,
  fetchzip,
}:

stdenvNoCC.mkDerivation {
  pname = "openclaw-app";
  version = "2026.4.12-beta.1";

  src = fetchzip {
    url = "https://github.com/openclaw/openclaw/releases/download/v2026.4.12-beta.1/OpenClaw-2026.4.12-beta.1.zip";
    hash = "sha256-EGGbqCRe0aQwgOQqwBYFgzmrN3T3LY0EBVQwgfkOW6c=";
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
