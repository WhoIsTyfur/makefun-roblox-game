// Hands in the Roblox entry: copies the built place, its Luau sources, screenshots and PLAY.json
// to the output directory, then writes dossier.json with make.fun's vendored library.
// Locally: MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const root = fileURLToPath(new URL('.', import.meta.url));
const dest = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

mkdirSync(dest, { recursive: true });
for (const file of ['game.rbxl', 'PLAY.json']) copyFileSync(join(root, file), join(dest, file));
cpSync(join(root, 'src'), join(dest, 'src'), { recursive: true });
mkdirSync(join(dest, 'screenshots'), { recursive: true });
if (existsSync(join(root, 'screenshots'))) {
  cpSync(join(root, 'screenshots'), join(dest, 'screenshots'), { recursive: true });
}

const caps = {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
};
writeFileSync(join(dest, 'dossier.json'), buildDossier(dest, caps));
