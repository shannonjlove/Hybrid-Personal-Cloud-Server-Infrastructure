// 00-setup-keychain.js
// Run this ONCE to store your server credentials securely in iOS Keychain.
// After this, all other scripts pull from Keychain — nothing is hardcoded.
//
// How to run: open in Scriptable, tap the play button.

const credentials = [
  {
    key:     "npm.url",
    label:   "NPM URL (public)",
    default: "https://npm.shannonjlove.cloud",
  },
  {
    key:     "npm.url.tailscale",
    label:   "NPM URL (Tailscale)",
    default: "http://shannonjlove.tail179603.ts.net:81",
  },
  {
    key:     "npm.email",
    label:   "NPM Email",
    default: "shannonjlove@mac.com",
  },
  {
    key:     "npm.password",
    label:   "NPM Password",
    default: "",
    secret:  true,
  },
  {
    key:     "memory.url",
    label:   "ai-memory URL",
    default: "https://memory.shannonjlove.cloud",
  },
];

for (const cred of credentials) {
  const existing = Keychain.contains(cred.key) ? Keychain.get(cred.key) : cred.default;
  const alert = new Alert();
  alert.title = `Set: ${cred.label}`;
  alert.message = cred.secret ? "Value is hidden for security." : `Current: ${existing || "(not set)"}`;
  alert.addTextField(cred.secret ? "Password" : cred.label, cred.secret ? "" : existing);
  alert.addAction("Save");
  alert.addCancelAction("Skip");

  const choice = await alert.presentAlert();
  if (choice === 0) {
    const value = alert.textFieldValue(0).trim() || existing;
    if (value) {
      Keychain.set(cred.key, value);
      console.log(`Saved: ${cred.key}`);
    }
  }
}

const done = new Alert();
done.title = "Keychain Setup Complete";
done.message = "All credentials stored securely. You can now run any other Scriptable script.";
done.addAction("OK");
await done.presentAlert();
