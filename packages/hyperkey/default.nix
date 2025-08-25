{
  lib,
  writeShellScriptBin,
}:

writeShellScriptBin "hyperkey" ''
  echo "⚠️  ERROR: HyperKey is DEPRECATED!"
  echo ""
  echo "This package has been replaced by a more modern solution."
  echo "Please use lazykeys instead: https://github.com/frostplexx/lazykeys"
  echo ""
  echo "To migrate:"
  echo "1. Remove services.hyperkey from your configuration"
  echo "2. Install and configure lazykeys instead"
  echo ""
  exit 1
'' // {
  meta = with lib; {
    description = "⚠️ DEPRECATED: Remaps Caps Lock to a Hyper key. Use lazykeys instead: https://github.com/frostplexx/lazykeys";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
