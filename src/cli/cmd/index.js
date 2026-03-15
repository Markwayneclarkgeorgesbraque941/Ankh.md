import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { runSetup } from "./setup.js";
import { runUninstall } from "./uninstall.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = join(__dirname, "../../..");

const HELP = `ankh - Agent Ankh management CLI

Usage: ankh COMMAND

Commands:
  setup        Check the installed Ankh runtime, PATH readiness, and Hermes global setup
  uninstall    Remove deployed Ankh runtime/wrappers and optionally Hermes/data
  --help       Show this help

Examples:
  ankh setup       # Verify the installed Ankh runtime, PATH, and Hermes global setup
  ankh uninstall   # Remove Ankh runtime and choose whether to keep Hermes/data
`;

export function printHelp() {
  console.log(HELP);
}

const cmd = {
  async setup() {
    await runSetup();
  },
  async uninstall() {
    await runUninstall();
  },
};

export default cmd;
