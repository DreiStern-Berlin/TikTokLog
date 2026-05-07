#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const { WebcastPushConnection } = require('tiktok-live-connector');

// --- Argumente ---
const argv = process.argv.slice(2);
let hostArg = null;
let nickArg = null;
let configPath = path.join(__dirname, 'config.json');

for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--Host' || a === '--host' || a === '-h') { hostArg = argv[i+1]; i++; }
  else if (a === '--Nick' || a === '-n') { nickArg = argv[i+1]; i++; }
  else if (a === '--config' || a === '-c') { configPath = argv[i+1]; i++; }
}

// --- Config laden ---
if (!fs.existsSync(configPath)) {
  console.error("config.json not found: " + configPath);
  process.exit(2);
}

const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const baseLogDir = path.isAbsolute(cfg.LogDirectory)
  ? cfg.LogDirectory
  : path.join(__dirname, cfg.LogDirectory);

// --- Host finden ---
function findHostEntry() {
  if (hostArg) {
    const h = String(hostArg).trim();
    return cfg.Hosts.find(x => x.name === h || x.nick === h);
  }
  if (nickArg) {
    const n = String(nickArg).trim();
    return cfg.Hosts.find(x => x.nick === n || x.name === n);
  }
  return null;
}

const hostEntry = findHostEntry();
if (!hostEntry) {
  console.error("Host/Nick not found in config: " + hostArg);
  process.exit(2);
}

const hostName = hostEntry.name;
const hostNick = hostEntry.nick;

// --- Logfile vorbereiten ---
const hostDirName = String(hostName).replace(/[^a-zA-Z0-9._-]/g, '_');
const hostLogDir = path.join(baseLogDir, hostDirName);
fs.mkdirSync(hostLogDir, { recursive: true });

function pad(n){ return String(n).padStart(2,'0'); }
function tsForFile(d = new Date()){
  return `${d.getFullYear()}${pad(d.getMonth()+1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`;
}

const logfile = path.join(hostLogDir, `Tiktok-Chat-${hostDirName}-${tsForFile()}.log`);
const logStream = fs.createWriteStream(logfile, { flags: 'a', encoding: 'utf8' });

function nowIso(){ return new Date().toISOString(); }
function emitToFile(obj){
  try { logStream.write(JSON.stringify(obj) + '\n'); } catch(_) {}
}

// --- TikTok Verbindung ---
const connection = new WebcastPushConnection(hostName);

// --- NUR Chat-Events loggen ---
connection.on('chat', (data) => {
  const payload = {
    timestamp: nowIso(),
    type: 'comment',
    host: hostName,
    nick: hostNick,
    nick: data.nickname || (data.user && data.user.nickname) || data.uniqueId  || (data.user && data.user.uniqueId) || 'unknown',
    username: data.uniqueId || (data.user && data.user.uniqueId) || 'unknown',
    text: data.comment || data.message || '',
    metadata: { event_type: 'comment' }
  };

  emitToFile(payload);
});

// --- Verbindung starten ---
connection.connect().catch(err => {
  console.error("Connection error: " + err);
  process.exit(1);
});
