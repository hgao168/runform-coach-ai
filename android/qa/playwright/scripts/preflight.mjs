import { execFileSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const failures = [];
const warnings = [];

function command(name, args) {
  try {
    return execFileSync(name, args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (error) {
    failures.push(`${name} ${args.join(' ')} failed: ${error.stderr?.trim() || error.message}`);
    return '';
  }
}

const nodeMajor = Number(process.versions.node.split('.')[0]);
if (nodeMajor < 20) failures.push(`Node 20+ is required; found ${process.version}`);
if (!existsSync('node_modules/@playwright/test')) {
  failures.push('Dependencies are absent. Run npm ci (or npm install before the first lockfile exists).');
}

const adbOutput = command('adb', ['devices']);
const online = adbOutput
  .split(/\r?\n/)
  .slice(1)
  .map(line => line.trim().split(/\s+/))
  .filter(([, state]) => state === 'device')
  .map(([serial]) => serial);

if (online.length === 0) failures.push('No online emulator/device reported by adb.');
if (online.length > 1 && !process.env.ANDROID_SERIAL) {
  failures.push(`Multiple devices are online (${online.join(', ')}); set ANDROID_SERIAL.`);
}
if (!process.env.APP_PACKAGE) {
  warnings.push('APP_PACKAGE is unset; the default com.runform will be used.');
}
if (!process.env.QA_EMAIL || !process.env.QA_PASSWORD) {
  warnings.push('QA credentials are unset; credential-dependent tests will be skipped.');
}

for (const warning of warnings) console.warn(`WARN: ${warning}`);
if (failures.length) {
  for (const failure of failures) console.error(`FAIL: ${failure}`);
  process.exit(1);
}
console.log(`PASS: Node ${process.versions.node}, adb device ${process.env.ANDROID_SERIAL || online[0]}`);
