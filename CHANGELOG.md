2026-07-17  Marc Wäckerlin

	* Neu: Verifikation der OpenPGP-Signatur des heruntergeladenen
	  SnappyMail-Release-Tarballs beim Docker-Build. Der öffentliche
	  Schlüssel ist als `snappymail-signing-key.asc` im Repo gepinnt;
	  der Build bricht ab, sobald eine der beiden Prüfungen fehlschlägt
	  (Platzhalter noch aktiv, gpg-Import defekt, Signatur passt nicht
	  zum Tarball).
	* README erklärt, wie der echte Schlüssel geholt, gegen die
	  Projekt-Fingerprint verifiziert und committet wird — inklusive
	  Rotation und Hinweis darauf, dass ein Rückgängig-Machen auf den
	  Platzhalter ein Sicherheitsvorfall ist.

2026-06-12  Marc Wäckerlin

	* PHP-Fehlerausgabe im FPM-Pool abgeschaltet, damit Deprecation-Warnungen
	  nicht mehr die JSON-Schnittstelle des Administrationsbereichs zerstören
	  und die Anmeldung verhindern.
	* Umgebungsvariablen werden an den FPM-Worker durchgereicht.
	* Datenverzeichnis-Volume auf den korrekten Pfad korrigiert, damit
	  Konfiguration und Konten dauerhaft erhalten bleiben.
