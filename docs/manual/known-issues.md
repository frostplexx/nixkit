# Known Issues {#ch-known-issues}

## Claude Code deduplicates MCP servers by command path {#sec-mcp-claude-code-dedup}

[Home Manager](https://github.com/nix-community/home-manager) provides a
`programs.mcp.servers` option for configuring MCP servers. When multiple servers use
the same binary (e.g. two instances of `prometheus-mcp-server` pointed at different
clusters), Claude Code (v2.1.71+) incorrectly treats them as duplicates and silently
drops all but one — even when their environment variables differ.

**Workaround:** wrap each server in a `pkgs.writeShellScriptBin` stub so each entry
gets a unique store path:

```nix
let
  mkWrapper = name:
    pkgs.writeShellScriptBin "prometheus-mcp-server-${name}" ''
      exec ${pkgs.prometheus-mcp-server}/bin/prometheus-mcp-server "$@"
    '';
in {
  programs.mcp.servers = {
    "prometheus/cluster-a" = {
      command = "${mkWrapper "cluster-a"}/bin/prometheus-mcp-server-cluster-a";
      args = [];
      env.PROMETHEUS_URL = "https://prometheus.cluster-a.example.com";
    };
    "prometheus/cluster-b" = {
      command = "${mkWrapper "cluster-b"}/bin/prometheus-mcp-server-cluster-b";
      args = [];
      env.PROMETHEUS_URL = "https://prometheus.cluster-b.example.com";
    };
  };
}
```

Tracked upstream at [anthropics/claude-code#32549](https://github.com/anthropics/claude-code/issues/32549).
