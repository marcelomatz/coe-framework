Locales = (type(Locales) == 'table' and Locales) or {}

Locales['en-US'] = {
	invoice_paid_autopay = 'Cell phone bill paid via auto-debit: %{amount}.',
	invoice_open_warning = 'Open cell phone bill: %{amount}. Pay in the My Line app within %{days} days.',
	line_suspended = 'Your line was suspended due to an overdue bill. Pay in the My Line app.'
}
