const { promises: fs } = require("fs");

let config;

async function initConfig() {
  console.log("init");
  config = JSON.parse((await fs.readFile("./config.json")).toString());
  return config;
}

function getConfig() {
  return config;
}

function setConfig(path, val) {
  console.log(config);
  const splitPath = path.split(".").reverse();

  let ref = config;
  while (splitPath.length > 1) {
    const key = splitPath.pop();
    if (key) {
      if (!ref[key]) ref[key] = {};
      ref = ref[key];
    } else {
      return;
    }
  }

  const key = splitPath.pop();
  if (key) ref[key] = val;
}

async function updateConfig() {
  console.log("write: ", JSON.stringify(config));

  return fs.writeFile("./config.json", JSON.stringify(config, null, 2));
}

module.exports = {
  initConfig,
  getConfig,
  setConfig,
  updateConfig,
};
