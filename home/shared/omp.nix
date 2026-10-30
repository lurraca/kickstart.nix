# oh-my-pi (omp) — pi fork with the IDE wired in (LSP, DAP, REPLs).
#
# Config layout:
#   - Declarative settings -> ~/.omp/agent/config.yml (writable copy, see the
#     upstream module's activation note about flock + atomic rewrites).
#   - Model providers: omp does NOT read ~/.pi/agent. models.json was copied
#     from the pi config into ~/.omp/agent/ and is auto-migrated to
#     models.yml on first launch (legacy migration path, docs/models.md).
#   - MCP servers: ~/.omp/agent/mcp.json (copied from pi; same format).
#   - Credentials: all gateway providers use $AI_GATEWAY_ACCESS_TOKEN
#     (launchctl setenv), so no auth.json needed.
#   - Skills: ~/.claude is scanned natively by omp, same as pi pointed to.
#
# pi stays installed and keeps its own state (sessions, models-store.json);
# the two agents coexist until omp is fully adopted. Model roles
# (modelRoles.default etc.) are deliberately NOT pinned here yet — being
# handled after first run via `omp config set` / /settings.
{
  inputs,
  ...
}: {
  imports = [ inputs.omp.homeManagerModules.default ];

  programs.omp.enable = true;
}
