import { join } from "node:path";
import { execFileSync } from "node:child_process";
import { getPkgRoot } from "../lib/paths.js";
import { runBashInline } from "../lib/spawn.js";
import { intro, outro, log, confirm, isCancel, cancel } from "../lib/clack.js";

const SETUP_SCRIPT = `
source "$AGENT_ANKH_PKG_ROOT/src/scripts/cli/cli.sh"
ensure_package_root
load_runtime_helper

if ! ankh_validate_install_integrity "$PKG_ROOT" "$ANKH_HOME" "$AGENT_BIN" "$ANKH_RUNTIME_DIR"; then
  ankh_print_integrity_report
  exit 1
fi
if ! ankh_validate_active_hermes_path "$AGENT_BIN"; then
  ankh_print_path_report "$AGENT_BIN"
  exit 1
fi
if ankh_is_configured; then
  echo "CONFIGURED"
  exit 0
fi
echo "NOT_CONFIGURED"
exit 0
`;

export async function runSetup() {
  const pkgRoot = getPkgRoot();
  const env = { AGENT_ANKH_PKG_ROOT: pkgRoot };

  try {
    const result = await runBashInline(SETUP_SCRIPT, { env, captureOutput: true });
    const out = (result?.stdout ?? "").trim();

    if (out === "CONFIGURED") {
      log.success("Agent Ankh is set up and ready.");
      log.message("Run 'hermes' in a directory with .agent already set up");
      log.message("Run 'hermes ankh' for Ankh management & usage info");
      return;
    }

    if (out === "NOT_CONFIGURED") {
      intro("Agent Ankh setup");
      log.message("Agent Ankh is installed but Hermes global setup is not yet ready.");
      const runHermes = await confirm({
        message: "Run Hermes setup?",
        initialValue: true,
      });
      if (isCancel(runHermes)) {
        cancel("Setup cancelled.");
        process.exit(0);
      }
      const home = process.env.HOME ?? process.env.USERPROFILE ?? "";
      const ankhBinDir =
        process.env.AGENT_BIN ??
        join(home, ".agent", "extensions", "ankh", "bin");
      const hermesBin = join(ankhBinDir, "hermes");
      if (runHermes) {
        outro("Running Hermes global setup...");
        execFileSync(hermesBin, ["setup"], {
          stdio: "inherit",
          env: { ...process.env, HERMES_ANKH_SCOPE: "global" },
        });
      } else {
        log.message(`When ready, run: HERMES_ANKH_SCOPE=global ${hermesBin} setup`);
        process.exit(1);
      }
      return;
    }

    log.error("Unexpected setup output.");
    process.exit(1);
  } catch (err) {
    if (err.stdout) process.stdout.write(err.stdout);
    if (err.stderr) process.stderr.write(err.stderr);
    process.exit(1);
  }
}
