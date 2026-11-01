Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	equipment_load_failed = 'Could not load equipment.',
	breaking_news = '%{outlet} · BREAKING: %{title}',
	article_published = '%{outlet} published your article "%{title}".',
	article_returned = '%{outlet} returned your article "%{title}" for revisions.',
	ad_rejected = '%{outlet} rejected your ad "%{title}". The amount was refunded.',
	ad_approved = '%{outlet} approved your ad "%{title}".',
	ad_expired = '%{outlet} did not respond to ad "%{title}". The amount was refunded.',
	ad_removed = '%{outlet} removed ad "%{title}".',
	ad_removed_refund = '%{outlet} removed ad "%{title}". Refund of %{amount}.',
	outlet_default = 'The vehicle'
}
