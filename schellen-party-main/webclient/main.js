let ws;
const messages = document.getElementById("messages");
const lobbyList = document.getElementById("lobbyList");
const joinBtn = document.getElementById("joinBtn");

joinBtn.onclick = () => {
    const name = document.getElementById("nameInput").value;
    if (!name) return;

    ws = new WebSocket("ws://"+location.hostname+":4322");

    ws.onopen = () => {
        ws.send(JSON.stringify({action:"join", name: name}));
        appendMessage("Verbunden als "+name);
    };

    ws.onmessage = (event) => {
        const obj = JSON.parse(event.data);
        if(obj.action == "player_list") {
            updateLobby(obj.players);
        } else if(obj.action == "start_game") {
            appendMessage("Spiel gestartet!");
            // Hier z.B. Spielfenster öffnen
        } else if(obj.action == "word") {
            appendMessage("Neues Wort: " + obj.word);
        }
    };

    ws.onclose = () => {
        appendMessage("Verbindung getrennt");
    };
};

function appendMessage(msg) {
    const li = document.createElement("li");
    li.textContent = msg;
    messages.appendChild(li);
}

function updateLobby(players) {
    lobbyList.innerHTML = "";
    players.forEach(name => {
        const li = document.createElement("li");
        li.textContent = name;
        lobbyList.appendChild(li);
    });
}
