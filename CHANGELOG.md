2026-06-12  Marc Wäckerlin

	* PHP-Fehlerausgabe im FPM-Pool abgeschaltet, damit Deprecation-Warnungen
	  nicht mehr die JSON-Schnittstelle des Administrationsbereichs zerstören
	  und die Anmeldung verhindern.
	* Umgebungsvariablen werden an den FPM-Worker durchgereicht.
	* Datenverzeichnis-Volume auf den korrekten Pfad korrigiert, damit
	  Konfiguration und Konten dauerhaft erhalten bleiben.
