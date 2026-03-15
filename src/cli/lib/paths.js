import { readFileSync } from "node:fs";
import { dirname, isAbsolute, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

let _vendorCache = null;

/** @returns {string} Absolute path to package root (ankh repo root). */
export function getPkgRoot() {
  return resolve(__dirname, "..", "..", "..");
}

/** @returns {object} Parsed vendor.json. */
function loadVendor() {
  if (_vendorCache) return _vendorCache;
  const vendorPath = join(getPkgRoot(), "src", "vendor.json");
  const raw = readFileSync(vendorPath, "utf-8");
  _vendorCache = JSON.parse(raw);
  return _vendorCache;
}

/** @returns {string} Version from source.version or env VERSION override. */
export function getVersion() {
  if (process.env.VERSION) return process.env.VERSION;
  const vendor = loadVendor();
  return vendor.source?.version ?? "main";
}

/** @returns {string} Absolute cache directory path. */
export function getCacheDir() {
  if (process.env.CACHE_DIR) {
    const root = getPkgRoot();
    const resolved = resolve(root, process.env.CACHE_DIR);
    const rel = relative(root, resolved);
    if (rel.startsWith("..") || isAbsolute(rel)) {
      throw new Error("CACHE_DIR must be under package root");
    }
    return resolved;
  }
  if (process.env.FRESH_CACHE === "1") {
    const pkgRoot = getPkgRoot();
    const version = getVersion();
    const timestamp = Date.now();
    const pid = process.pid;
    return join(pkgRoot, ".build", "cache", `${version}-${timestamp}-${pid}`);
  }
  const pkgRoot = getPkgRoot();
  const vendor = loadVendor();
  const version = getVersion();
  const cacheTpl = vendor.paths?.cache ?? "./.build/cache/{version}";
  const cacheRel = cacheTpl.replace("{version}", version);
  return resolve(pkgRoot, cacheRel);
}

/** @returns {string} Absolute build directory path. */
export function getBuildDir() {
  if (process.env.BUILD_DIR) {
    const root = getPkgRoot();
    const resolved = resolve(root, process.env.BUILD_DIR);
    const rel = relative(root, resolved);
    if (rel.startsWith("..") || isAbsolute(rel)) {
      throw new Error("BUILD_DIR must be under package root");
    }
    return resolved;
  }
  const pkgRoot = getPkgRoot();
  const vendor = loadVendor();
  const buildRel = vendor.paths?.build ?? "./.build";
  return resolve(pkgRoot, buildRel);
}

/** @returns {string} Path to install.sh */
export function getInstallScriptPath() {
  return join(getPkgRoot(), "src", "scripts", "build", "install.sh");
}

/** @returns {string} Path to build.sh */
export function getBuildScriptPath() {
  return join(getPkgRoot(), "src", "scripts", "build", "build.sh");
}

/** @returns {string} Path to deploy.sh */
export function getDeployScriptPath() {
  return join(getPkgRoot(), "src", "scripts", "build", "deploy.sh");
}

/** @returns {string} Path to runtime-state.sh */
export function getRuntimeStatePath() {
  return join(getPkgRoot(), "src", "scripts", "cli", "runtime-state.sh");
}
