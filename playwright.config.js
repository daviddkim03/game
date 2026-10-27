const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './tests',
  fullyParallel: true,
  use: {
    viewport: { width: 1440, height: 1000 },
    trace: 'retain-on-failure',
  },
});
