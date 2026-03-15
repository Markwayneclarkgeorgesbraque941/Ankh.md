import { spawn } from "node:child_process";

/**
 * Spawns bash to run an inline command.
 *
 * @param {string} command - Bash command string
 * @param {object} [opts] - Options
 * @param {string} [opts.cwd] - Working directory (default: process.cwd())
 * @param {object} [opts.env] - Env vars merged with process.env
 * @returns {Promise<void>} Resolves on success, rejects on non-zero exit
 */
export function runBashCommand(command, opts = {}) {
  const { cwd = process.cwd(), env = {} } = opts;
  const mergedEnv = { ...process.env, ...env };
  return new Promise((resolve, reject) => {
    const child = spawn("bash", ["-c", command], {
      cwd,
      env: mergedEnv,
      stdio: "pipe",
    });
    child.on("error", reject);
    child.on("close", (code, signal) => {
      if (code !== 0) {
        const msg = signal
          ? `Command exited with signal ${signal}`
          : `Command exited with code ${code}`;
        reject(new Error(msg));
      } else {
        resolve();
      }
    });
  });
}

/**
 * Spawns bash to run a script.
 *
 * @param {string} scriptPath - Path to the bash script
 * @param {object} [opts] - Options
 * @param {string} [opts.cwd] - Working directory (default: process.cwd())
 * @param {object} [opts.env] - Env vars merged with process.env
 * @param {string} [opts.stdio='inherit'] - stdio mode when taskLog omitted; ignored when taskLog provided
 * @param {(chunk: string) => void} [opts.taskLog] - If provided, stream stdout/stderr here; else to process.stdout/process.stderr
 * @returns {Promise<void>} Resolves on success, rejects on non-zero exit
 */
export function runBashScript(scriptPath, opts = {}) {
  const {
    cwd = process.cwd(),
    env = {},
    stdio,
    taskLog,
  } = opts;

  const mergedEnv = { ...process.env, ...env };
  const useTaskLog = typeof taskLog === "function";
  const spawnStdio = useTaskLog ? "pipe" : (stdio ?? "inherit");

  return new Promise((resolve, reject) => {
    const child = spawn("bash", [scriptPath], {
      cwd,
      env: mergedEnv,
      stdio: spawnStdio,
    });

    if (useTaskLog) {
      const forward = (chunk) => {
        if (chunk) taskLog(chunk.toString());
      };
      child.stdout?.on("data", forward);
      child.stderr?.on("data", forward);
    }

    child.on("error", reject);
    child.on("close", (code, signal) => {
      if (code !== 0) {
        const msg = signal
          ? `Script exited with signal ${signal}`
          : `Script exited with code ${code}`;
        reject(new Error(msg));
      } else {
        resolve();
      }
    });
  });
}

/**
 * Spawns bash -c with an inline script.
 *
 * @param {string} script - Inline bash script
 * @param {object} [opts] - Options
 * @param {string} [opts.cwd] - Working directory (default: process.cwd())
 * @param {object} [opts.env] - Env vars merged with process.env
 * @param {string} [opts.stdio='inherit'] - stdio mode when captureOutput false; use 'pipe' when captureOutput true
 * @param {boolean} [opts.captureOutput] - If true, stdio is pipe and resolves with { stdout, stderr }
 * @returns {Promise<void|{stdout:string,stderr:string}>} Resolves on success; with captureOutput, returns { stdout, stderr }
 */
export function runBashInline(script, opts = {}) {
  const {
    cwd = process.cwd(),
    env = {},
    stdio,
    captureOutput = false,
  } = opts;

  const mergedEnv = { ...process.env, ...env };
  const spawnStdio = captureOutput ? "pipe" : (stdio ?? "inherit");

  return new Promise((resolve, reject) => {
    const child = spawn("bash", ["-c", script], {
      cwd,
      env: mergedEnv,
      stdio: spawnStdio,
    });

    let stdout = "";
    let stderr = "";
    if (captureOutput) {
      child.stdout?.on("data", (chunk) => { stdout += chunk.toString(); });
      child.stderr?.on("data", (chunk) => { stderr += chunk.toString(); });
    }

    child.on("error", reject);
    child.on("close", (code, signal) => {
      if (code !== 0) {
        const msg = signal
          ? `Script exited with signal ${signal}`
          : `Script exited with code ${code}`;
        const err = new Error(msg);
        if (captureOutput) {
          err.stdout = stdout;
          err.stderr = stderr;
        }
        reject(err);
      } else {
        resolve(captureOutput ? { stdout, stderr } : undefined);
      }
    });
  });
}
