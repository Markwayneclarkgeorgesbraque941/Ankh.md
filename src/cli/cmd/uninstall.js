import { join } from "node:path";
import { spawn } from "node:child_process";
import { getPkgRoot } from "../lib/paths.js";
import { group, confirm, isCancel, cancel, outro } from "../lib/clack.js";

/**
 * Parses yes/no from env value. Returns true for yes, false for no.
 * @param {string} [val] - Raw value (yes, y, 1, true, no, n, 0, false)
 * @returns {boolean|undefined} true/false when parseable, undefined when empty
 */
function parseYesNo(val) {
  if (val == null || String(val).trim() === "") return undefined;
  const s = String(val).trim().toLowerCase();
  if (["yes", "y", "1", "true", "on"].includes(s)) return true;
  if (["no", "n", "0", "false", "off"].includes(s)) return false;
  return undefined;
}

export async function runUninstall() {
  const hasEnv =
    process.env.KEEP_HERMES != null ||
    process.env.KEEP_ANKH_DATA != null ||
    process.env.KEEP_HERMES_DATA != null;

  let keepHermes;
  let keepAnkhData;
  let keepHermesData;

  if (hasEnv) {
    keepHermes = parseYesNo(process.env.KEEP_HERMES) ?? true;
    keepAnkhData = parseYesNo(process.env.KEEP_ANKH_DATA) ?? true;
    keepHermesData = parseYesNo(process.env.KEEP_HERMES_DATA) ?? true;
  } else {
    const result = await group(
      {
        keepHermes: () =>
          confirm({
            message: "Keep Hermes?",
            initialValue: true,
          }),
        keepAnkhData: () =>
          confirm({
            message: "Keep Ankh global data?",
            initialValue: true,
          }),
        keepHermesData: ({ results }) =>
          results.keepHermes
            ? Promise.resolve(true)
            : confirm({
                message: "Keep Hermes global data?",
                initialValue: true,
              }),
      },
      {
        onCancel: () => {
          cancel("Uninstall cancelled.");
          process.exit(0);
        },
      }
    );

    if (isCancel(result)) {
      cancel("Uninstall cancelled.");
      process.exit(0);
    }

    keepHermes = result.keepHermes;
    keepAnkhData = result.keepAnkhData;
    keepHermesData = result.keepHermesData;
  }

  const env = {
    ...process.env,
    AGENT_ANKH_PKG_ROOT: getPkgRoot(),
    KEEP_HERMES: keepHermes ? "yes" : "no",
    KEEP_ANKH_DATA: keepAnkhData ? "yes" : "no",
    KEEP_HERMES_DATA: keepHermesData ? "yes" : "no",
  };

  const cliPath = join(getPkgRoot(), "src", "scripts", "cli", "cli.sh");

  await new Promise((resolve, reject) => {
    const proc = spawn("bash", [cliPath, "uninstall"], {
      stdio: "inherit",
      env,
    });
    proc.on("close", (code) =>
      code === 0 ? resolve() : reject(new Error(`Exit ${code}`))
    );
  });

  outro("Agent Ankh uninstall complete.");
}
