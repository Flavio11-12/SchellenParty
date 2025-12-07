// server.js
const WebSocket = require("ws");

// WebSocket-Server auf Port 8080
const wss = new WebSocket.Server({ port: 8080 });

console.log("Schellenparty WebSocket-Server läuft auf ws://localhost:8080");

// einfache Speicherstruktur für Spieler
// key: WebSocket-Objekt, value: { id, name }
const players = new Map();
let nextPlayerId = 1;

// Hilfsfunktion: an einen Client senden
function send(ws, type, payload = {}) {
  const message = JSON.stringify({ type, payload });
  ws.send(message);
}

// Hilfsfunktion: an alle senden
function broadcast(type, payload = {}) {
  const message = JSON.stringify({ type, payload });
  for (const ws of wss.clients) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(message);
    }
  }
}

// Verbindungsevent
wss.on("connection", (ws) => {
  const playerId = nextPlayerId++;
  players.set(ws, { id: playerId, name: `Player${playerId}` });

  console.log(`Client verbunden: #${playerId}`);

  // Begrüßungsnachricht an neuen Client
  send(ws, "WELCOME", {
    id: playerId,
    message: "Willkommen bei Schellenparty!",
  });

  // allen sagen, dass ein neuer Spieler da ist
  broadcast("PLAYER_JOINED", {
    id: playerId,
    name: `Player${playerId}`,
  });

  // Nachrichten vom Client
  ws.on("message", (data) => {
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch (e) {
      console.log("Ungültige Nachricht:", data.toString());
      return;
    }

    const { type, payload } = msg;
    const player = players.get(ws);

    if (!player) return;

    switch (type) {
      case "SET_NAME":
        // Spieler kann seinen Namen ändern
        player.name = payload.name || player.name;
        console.log(`Spieler #${player.id} heißt jetzt ${player.name}`);
        broadcast("PLAYER_RENAMED", {
          id: player.id,
          name: player.name,
        });
        break;

      case "PING":
        // einfache Verbindungstest-Nachricht
        send(ws, "PONG", { time: Date.now() });
        break;

      case "CHAT":
        // ganz simpler Chat als Beispiel
        console.log(`CHAT von ${player.name}: ${payload.message}`);
        broadcast("CHAT", {
          from: player.name,
          message: payload.message,
        });x
        break;

      default:
        console.log("Unbekannter Nachrichtentyp:", type);
    }
  });

  // Verbindung beendet
  ws.on("close", () => {
    const player = players.get(ws);
    if (player) {
      console.log(`Client getrennt: #${player.id}`);
      players.delete(ws);
      broadcast("PLAYER_LEFT", { id: player.id, name: player.name });
    }
  });
});