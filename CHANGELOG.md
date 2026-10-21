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
