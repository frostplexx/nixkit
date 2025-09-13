{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs,
  pnpm_9,
  geist-font,
}: let
  rev = "d910aec1aebdc6d76d72229b809b8cedff048b58";
  version = "unstable-${builtins.substring 0 7 rev}";
  src = fetchFromGitHub {
    owner = "l2xu";
    repo = "betterbahn";
    inherit rev;
    hash = "sha256-ffNsuaBrow/Fz6TbjoO3eMK0DdRS/AFVYWk+obzHvF8=";
  };
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "betterbahn";
    inherit version src;

    nativeBuildInputs = [
      nodejs
      pnpm_9.configHook
    ];

    postPatch = ''
      # Fix pnpm workspace configuration
      echo "packages:" > pnpm-workspace.yaml
      echo "  - ." >> pnpm-workspace.yaml
    '';

    preBuild = ''
      # Disable Next.js telemetry
      export NEXT_TELEMETRY_DISABLED=1

      # Enable standalone mode for proper static asset handling
      echo 'module.exports = { output: "standalone" }' > next.config.js

      # Copy Geist fonts to app/fonts directory where Next.js expects them
      mkdir -p app/fonts
      cp "${geist-font}"/share/fonts/opentype/Geist-Regular.otf app/fonts/
      cp "${geist-font}"/share/fonts/opentype/GeistMono-Regular.otf app/fonts/

      # Replace Google Font imports with local font imports
      sed -i 's/import { Geist, Geist_Mono } from "next\/font\/google"/import localFont from "next\/font\/local"/' app/layout.tsx
      sed -i 's/const geistSans = Geist({/const geistSans = localFont({/' app/layout.tsx
      sed -i 's/const geistMono = Geist_Mono({/const geistMono = localFont({/' app/layout.tsx
      sed -i 's/variable: "--font-geist-sans",/src: ".\/fonts\/Geist-Regular.otf",\n    variable: "--font-geist-sans",/' app/layout.tsx
      sed -i 's/variable: "--font-geist-mono",/src: ".\/fonts\/GeistMono-Regular.otf",\n    variable: "--font-geist-mono",/' app/layout.tsx
      sed -i '/subsets: \["latin"\],/d' app/layout.tsx
    '';

    pnpmDeps = pnpm_9.fetchDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 2;
      postPatch = ''
        # Fix pnpm workspace configuration
        echo "packages:" > pnpm-workspace.yaml
        echo "  - ." >> pnpm-workspace.yaml
      '';
      hash = "sha256-dstLwlaUUMjE7SUaFXPiN/yl15bezq/SIFW7O3ZA10Q=";
    };

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/betterbahn
      cp -r .next/standalone/* $out/lib/betterbahn/

      # Copy static assets to the correct location within standalone
      mkdir -p $out/lib/betterbahn/.next
      cp -r .next/static $out/lib/betterbahn/.next/

      # Copy the build manifest and other necessary files
      if [ -f .next/BUILD_ID ]; then
        cp .next/BUILD_ID $out/lib/betterbahn/.next/
      fi

      if [ -f .next/build-manifest.json ]; then
        cp .next/build-manifest.json $out/lib/betterbahn/.next/
      fi
      # Copy the built application
      mkdir -p $out/lib/betterbahn
      cp -r . $out/lib/betterbahn/
      cp -r .next $out/lib/betterbahn/

      mkdir -p $out/bin
      cat > $out/bin/betterbahn << EOF
      #!/usr/bin/env bash
      cd $out/lib/betterbahn
      export NODE_ENV=production
      export PORT=\${PORT:-3000}
      echo "Starting BetterBahn on port \$PORT"
      echo "<C-z> to kill the server"
      exec ${nodejs}/bin/node server.js "\$@"
      EOF
      chmod +x $out/bin/betterbahn

      runHook postInstall
    '';

    meta = with lib; {
      description = "A web app for finding the best train journeys in Germany";
      homepage = "https://github.com/l2xu/betterbahn";
      license = licenses.agpl3Only;
      mainProgram = "betterbahn";
    };
  })
