(rl => {
	if (!rl) {
		return;
	}

	const BANNER_ID = 'transport-security-banner';

	// Map an X-Transport-Security value to a banner, or null for a
	// modern-TLS mail that needs no warning.
	const classify = raw => {
		const v = (raw || '').trim();
		if (!v || 'none' === v.toLowerCase()) {
			return { level: 'insecure',
				text: '⚠ This message was transported UNENCRYPTED' };
		}
		const m = v.match(/TLSv([0-9.]+)/i);
		if (m && parseFloat(m[1]) < 1.2) {
			return { level: 'weak',
				text: '⚠ Obsolete transport encryption: ' + v };
		}
		return null;
	};

	const removeBanner = root =>
		(root.querySelector ? root : document)
			.querySelector('#' + BANNER_ID)?.remove();

	const showBanner = (root, info) => {
		const host = root.querySelector ? root : document.body;
		removeBanner(host);
		if (!info) {
			return;
		}
		const el = Element.fromHTML(
			'<div id="' + BANNER_ID + '" class="transport-security transport-'
			+ info.level + '" role="alert">' + info.text + '</div>');
		host.prepend(el);
	};

	addEventListener('rl-view-model.create', e => {
		const view = e.detail;
		if (!view || 'MailMessageView' !== view.viewModelTemplateID) {
			return;
		}
		const root = view.viewModelDom || document;
		if (!view.message || !view.message.subscribe) {
			return;
		}
		view.message.subscribe(msg => {
			removeBanner(root);
			if (!msg) {
				return;
			}
			const folder = msg.folder,
				uid = ('function' === typeof msg.uid) ? msg.uid() : msg.uid;
			rl.pluginRemoteRequest((iError, oData) => {
				if (iError || !oData || !oData.Result) {
					return;
				}
				showBanner(root, classify(oData.Result.value));
			}, 'TransportSecurity', { Folder: folder, Uid: uid });
		});
	});
})(window.rl);
