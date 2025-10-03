const fs = require("fs");
const yaml = require("js-yaml");
const pkg = require("../package.json");

const CONFIG_FILE = "config.yml";

try {
  // Load YAML
  const config = yaml.load(fs.readFileSync(CONFIG_FILE, "utf8"));

  // Update name with version
  const baseName = config.name.replace(/\sv\d+\.\d+\.\d+$/, ""); // strip old version
  config.name = `${baseName} v${pkg.version}`;

  // Save YAML back
  fs.writeFileSync(CONFIG_FILE, yaml.dump(config), "utf8");
  console.log(`Updated ${CONFIG_FILE} name → ${config.name}`);
} catch (e) {
  console.error("Failed to update config.yml:", e);
  process.exit(1);
}