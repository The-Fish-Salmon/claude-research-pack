#!/usr/bin/env node
// Wraps mcp-obsidian and patches tool inputSchemas to add "type":"object",
// which Claude Code requires but mcp-obsidian omits.
//
// Resolves mcp-obsidian via Node's module resolution from this wrapper's location,
// so it works on WSL, Windows native, and Claude Desktop without hardcoded paths.
// Install layout: this file lives in <claude>/mcp-servers/obsidian-wrapper.js, with
// a sibling node_modules/mcp-obsidian/ folder created by the installer's `npm install`.
const path = require('path');
const { spawn } = require('child_process');
const readline = require('readline');

function resolveMcpObsidian() {
  // Try in order:
  //  1. node_modules sibling (the installer installs mcp-obsidian here)
  //  2. require.resolve from cwd
  //  3. global npx cache (last-resort fallback for dev rigs)
  const tryPaths = [
    path.join(__dirname, 'node_modules', 'mcp-obsidian', 'dist', 'index.js'),
  ];
  for (const p of tryPaths) {
    try { require('fs').accessSync(p); return p; } catch { /* not here */ }
  }
  try {
    return require.resolve('mcp-obsidian/dist/index.js', { paths: [__dirname, process.cwd()] });
  } catch {
    process.stderr.write(
      '[obsidian-wrapper] could not locate mcp-obsidian. Install it next to this wrapper: ' +
      `cd "${__dirname}" && npm install mcp-obsidian\n`
    );
    process.exit(1);
  }
}

const target = resolveMcpObsidian();
// mcp-obsidian requires <vault-directory> as argv[1]. Prefer an explicit CLI
// arg (so callers can override), fall back to OBSIDIAN_VAULT_PATH from the
// inherited environment, which is how the install pack exposes the vault.
let args = process.argv.slice(2);
if (args.length === 0 && process.env.OBSIDIAN_VAULT_PATH) {
  args = [process.env.OBSIDIAN_VAULT_PATH];
}
if (args.length === 0) {
  process.stderr.write(
    '[obsidian-wrapper] no vault directory provided. Pass one as an arg or set OBSIDIAN_VAULT_PATH.\n'
  );
  process.exit(1);
}
const child = spawn(
  process.execPath,
  [target, ...args],
  { stdio: ['pipe', 'pipe', 'inherit'] }
);

const rl = readline.createInterface({ input: child.stdout });

rl.on('line', (line) => {
  try {
    const msg = JSON.parse(line);
    if (msg.result && Array.isArray(msg.result.tools)) {
      msg.result.tools = msg.result.tools.map((tool) => {
        if (tool.inputSchema && !tool.inputSchema.type) {
          tool.inputSchema = { type: 'object', ...tool.inputSchema };
        }
        return tool;
      });
    }
    process.stdout.write(JSON.stringify(msg) + '\n');
  } catch {
    process.stdout.write(line + '\n');
  }
});

process.stdin.pipe(child.stdin);
child.on('exit', (code) => process.exit(code ?? 0));
