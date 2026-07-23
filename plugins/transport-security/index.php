<?php

/**
 * SnappyMail plugin: surface the transport encryption of an incoming
 * mail in the message view.
 *
 * The mailservice MX stamps a machine-readable `X-Transport-Security`
 * header on every incoming mail (rspamd, from the postfix TLS session):
 *   TLSv1.3 (cipher …)  — encrypted with a modern protocol
 *   TLSv1.0 / TLSv1.1   — obsolete protocol
 *   none                — the sender delivered in the clear
 *
 * This plugin reads that header for the opened message (server-side, via
 * IMAP — the frontend never sees a value the server did not vouch for)
 * and the bundled message.js renders a coloured banner: red for
 * cleartext, orange for an obsolete TLS version, nothing for TLS 1.2+.
 * So the user can tell at a glance which correspondents deliver
 * insecurely and warn them.
 */

use RainLoop\Plugins\AbstractPlugin;

class TransportSecurityPlugin extends AbstractPlugin
{
	const
		NAME        = 'Transport Security',
		AUTHOR      = 'Marc Wäckerlin',
		URL         = 'https://mwaeckerlin.ch',
		VERSION     = '1.0',
		RELEASE     = '2026-07-20',
		REQUIRED    = '2.28.0',
		CATEGORY    = 'Security',
		LICENSE     = 'GPL-3.0',
		DESCRIPTION = 'Marks how securely each incoming mail was transported (X-Transport-Security), red for cleartext.';

	public function Init(): void
	{
		$this->addCss('style.css');
		$this->addJs('message.js');
		$this->addJsonHook('TransportSecurity', 'DoTransportSecurity');
	}

	/**
	 * Returns the X-Transport-Security header of one message.
	 * Request params: Folder (string), Uid (string/int).
	 * Response: { value: "<header or empty>" }.
	 */
	public function DoTransportSecurity(): array
	{
		$sFolder = $this->jsonParam('Folder', '');
		$sUid    = (string) $this->jsonParam('Uid', '');
		$sValue  = '';

		if (\strlen($sFolder) && \strlen($sUid) && \ctype_digit($sUid)) {
			$oActions    = \RainLoop\Api::Actions();
			$oAccount    = $oActions->getAccountFromToken();
			$oMailClient = $oActions->MailClient();
			if (!$oMailClient->IsLoggined()) {
				$oAccount->ImapConnectAndLogin(
					$oActions->Plugins(),
					$oMailClient->ImapClient(),
					$oActions->Config()
				);
			}
			$oImap = $oMailClient->ImapClient();
			$oImap->FolderSelect($sFolder);
			// Fetch just the one header (BODY.PEEK — never sets \Seen).
			$aFetch = $oImap->Fetch(
				[\MailSo\Imap\Enumerations\FetchType::BODY_HEADER_PEEK],
				$sUid,
				true
			);
			foreach ($aFetch as $oResponse) {
				$sHeaders = $oResponse->GetFetchValue(
					\MailSo\Imap\Enumerations\FetchType::BODY_HEADER
				);
				if (\is_string($sHeaders) &&
					\preg_match('/^X-Transport-Security:\s*(.+)$/im', $sHeaders, $m)) {
					$sValue = \trim($m[1]);
					break;
				}
			}
		}

		return $this->jsonResponse(__FUNCTION__, ['value' => $sValue]);
	}
}
