2026-10-24  Marc Wäckerlin

	* Der Build nimmt das neueste SnappyMail-Release, dessen Tarball sich
	  herunterladen lässt. v2.38.2.1 erschien ohne Dateien, releases/latest
	  zeigte darauf, und jeder Build brach mit 404 ab; ein Release, dessen
	  Dateien noch fehlen, wird übersprungen, bis sie da sind.
	* Das nginx-Image baut ohne Warnung der Docker-Build-Prüfungen.

2026-10-21  Marc Wäckerlin

	* Die Versionslinie 1 wird wieder gebaut und veröffentlicht, als
	  mwaeckerlin/rainloop:php-fpm-1 und nginx-1, bei jedem Push auf diesen
	  Branch und jede Woche mit dem Lauf auf master. Bisher bekam sie keinen
	  Neubau und damit keine Sicherheitskorrektur ihres Basis-Images, zuletzt
	  die Gegenmassnahmen gegen CVE-2026-109618 und CVE-2026-109619 aus
	  mwaeckerlin/php-fpm. Ein Test prüft, dass sie im Image wirken.

2026-06-12  Marc Wäckerlin

	* PHP-Fehlerausgabe im FPM-Pool abgeschaltet, damit Deprecation-Warnungen
	  nicht mehr die JSON-Schnittstelle des Administrationsbereichs zerstören
	  und die Anmeldung verhindern.
	* Umgebungsvariablen werden an den FPM-Worker durchgereicht.
	* Datenverzeichnis-Volume auf den korrekten Pfad korrigiert, damit
	  Konfiguration und Konten dauerhaft erhalten bleiben.
