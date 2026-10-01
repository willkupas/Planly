// Roda os testes de integração no Emulator Suite com App Check exigido (ENFORCE_APP_CHECK_IN_EMULATOR),
// de forma portátil (Windows/Linux). Uso: npm run test:integration
import { spawnSync } from "node:child_process";

const testCmd =
  'node --test --test-concurrency=1 .test-build/test/integration/**/*.test.js';

const r = spawnSync(
  "firebase",
  [
    "emulators:exec",
    "--config",
    "firebase.test.json",
    "--only",
    "auth,firestore,functions",
    "--project",
    "demo-planly-functions",
    `"${testCmd}"`, // com shell:true o argumento precisa de aspas próprias
  ],
  {
    stdio: "inherit",
    shell: true,
    // PUSH_FAKE_IN_EMULATOR: o FCM não é emulado; os triggers de push gravam em _pushOutbox.
    env: { ...process.env, ENFORCE_APP_CHECK_IN_EMULATOR: "true", PUSH_FAKE_IN_EMULATOR: "true" },
  },
);

process.exit(r.status ?? 1);
