// npm-manager.js
// Control Nginx Proxy Manager from iOS.
// Lists all proxy hosts, lets you enable/disable them, and add the
// memory.shannonjlove.cloud host in one tap.
//
// Requires: run 00-setup-keychain.js first.

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------
const NPM_URL = Keychain.contains("npm.url")
  ? Keychain.get("npm.url")
  : "https://npm.shannonjlove.cloud";

async function getToken() {
  const req = new Request(`${NPM_URL}/api/tokens`);
  req.method = "POST";
  req.headers = { "Content-Type": "application/json" };
  req.body = JSON.stringify({
    identity: Keychain.get("npm.email"),
    secret:   Keychain.get("npm.password"),
  });
  const res = await req.loadJSON();
  if (!res.token) throw new Error("NPM auth failed — check credentials.");
  return res.token;
}

function authed(token) {
  return { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };
}

async function npmGet(token, path) {
  const req = new Request(`${NPM_URL}/api${path}`);
  req.headers = authed(token);
  return req.loadJSON();
}

async function npmPut(token, path, body) {
  const req = new Request(`${NPM_URL}/api${path}`);
  req.method = "PUT";
  req.headers = authed(token);
  req.body = JSON.stringify(body);
  return req.loadJSON();
}

async function npmPost(token, path, body) {
  const req = new Request(`${NPM_URL}/api${path}`);
  req.method = "POST";
  req.headers = authed(token);
  req.body = JSON.stringify(body);
  return req.loadJSON();
}

// ---------------------------------------------------------------------------
// Main UI
// ---------------------------------------------------------------------------
const token = await getToken();
const hosts = await npmGet(token, "/nginx/proxy-hosts");

const table = new UITable();
table.showSeparators = true;

// Header
const header = new UITableRow();
header.isHeader = true;
const headerCell = header.addText("Nginx Proxy Manager");
headerCell.titleFont = Font.boldSystemFont(16);
table.addRow(header);

// Proxy host rows
for (const host of hosts) {
  const row = new UITableRow();
  row.height = 56;

  const domain = host.domain_names.join(", ");
  const target = `${host.forward_host}:${host.forward_port}`;
  const status = host.enabled ? "✅" : "⛔️";

  const nameCell = row.addText(`${status} ${domain}`, target);
  nameCell.titleFont = Font.systemFont(14);
  nameCell.subtitleFont = Font.systemFont(11);
  nameCell.subtitleColor = Color.gray();

  const toggleCell = row.addButton(host.enabled ? "Disable" : "Enable");
  toggleCell.onTap = async () => {
    await npmPut(token, `/nginx/proxy-hosts/${host.id}`, {
      ...host,
      enabled: !host.enabled,
    });
    Script.complete();
  };

  table.addRow(row);
}

// Add row for memory host
const addRow = new UITableRow();
addRow.height = 48;
const addCell = addRow.addButton("＋  Add memory.shannonjlove.cloud");
addCell.onTap = async () => {
  const res = await npmPost(token, "/nginx/proxy-hosts", {
    domain_names:          ["memory.shannonjlove.cloud"],
    forward_scheme:        "http",
    forward_host:          "127.0.0.1",
    forward_port:          9077,
    ssl_forced:            false,
    block_exploits:        true,
    allow_websocket_upgrade: true,
    http2_support:         false,
    enabled:               true,
    locations:             [],
    certificate_id:        0,
    access_list_id:        0,
    meta: { letsencrypt_agree: false, dns_challenge: false },
  });
  const alert = new Alert();
  alert.title = res.id ? "Host Created" : "Error";
  alert.message = res.id ? `memory.shannonjlove.cloud created (id ${res.id})` : JSON.stringify(res);
  alert.addAction("OK");
  await alert.presentAlert();
  Script.complete();
};
table.addRow(addRow);

await table.present();
