#Schellenparty

##1. Projektidee und Ziel
Kurze Beschreibung: „Schellenparty“ ist ein browserbasiertes Multiplayer-Spiel, ähnlich wie Bombenparty (jklm.fun), bei dem Spieler in Echtzeit miteinander interagieren.
Ziel: Ein leicht zugängliches Partyspiel mit zentralem Server, Lobby-System und synchronem Spielfluss.
Fragestellung: Wie kann mit Godot ein browserbasiertes Multiplayerspiel entwickelt werden?
##2. Spielprinzip
Core-Gameplay: In der Hand stehen Buchstabenkombination von Worten 
(zb. „st“). Der Spieler, der dran ist, muss ein Wort finden und eingeben was „st“ beinhaltet (zb. “Stock“). Dieser Spieler übergibt dann die Hand an den nächsten Spieler mit einer neuen Buchstabenkombination.
Interaktion: Wie kommunizieren die Spieler (visuell, akustisch, Eingaben)?
 
##3. Technische Architektur
Browser-basiert: Client läuft im Webbrowser, kein Download nötig.
Kommunikation:
Unicast / WebSocket – direkter Server-Client-Austausch in Echtzeit.
Central GameState – zentral verwalteter Zustand des laufenden Spiels.
Server-Backend: Node.js mit WebSocket-Framework (z. B. Socket.io).
Skalierung: Spieleranzahl/Lobbies größe
 
##4. Lobby-System
Erstellung und Beitritt: Spieler können Lobbys erstellen, beitreten, verlassen.
Spielerzuordnung: Verwaltung von Spielern, Namen, Leben.
Skalierung: Dynamische Erstellung neuer Lobbys bei hoher Auslastung.
 
##5. Synchronisation & GameState-Management
Serverseitig: Der zentrale Spielzustand liegt auf dem Server.
Clientseitig: Regelmäßige Updates über WebSocket; minimaler Lag.
Fehlerhandling: Reconnect, Timeouts, Zustandsprüfung bei Latenz.
 
##6. Datenbank
Wörter: Wörter werden aus der Datenbank benutzt
Technologie: MongoDB, MariaDB (je nach Architektur).
 
##7. Entwicklungsumgebung & Technologie
Engine: Godot (für das Frontend/UI und Spielmechanik).
Sprache: GDScript + JavaScript (Node.js).
Editor / Tools: VSCode, Git, lokale Testserver.
 
##8. Webdesign & UI
Frontend: HTML, CSS, ggf. GodotUI (je nach Implementierung).
Designstil: Minimalistisch, klare Farbkontraste, schnelle Lesbarkeit.
Responsivität: Funktioniert auf Desktop, Tablet, Smartphone.

<img width="454" height="714" alt="image" src="https://github.com/user-attachments/assets/16e1ac6e-717c-4e00-a23d-bbc9a1c8eaca" />
