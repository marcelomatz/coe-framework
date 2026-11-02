'use strict';

const GENERIC_DESCRIPTIONS = /^(?:todo|tbd|n\/?a|none|no description(?: available)?|description unavailable|not documented|coming soon|export description|function description)[.!:]?$/i;

function hasEnglishDescription(value) {
	return typeof value === 'string' && value.trim().length > 0 && !GENERIC_DESCRIPTIONS.test(value.trim());
}

function countMissingEnglishExportDescriptions(resources, catalog, referenceDescriptions) {
	const catalogById = new Map(catalog.map(script => [
		script.id,
		new Map((script.exports || []).map(entry => [String(entry.name).split('(')[0].trim(), entry.desc])),
	]));
	let missing = 0;
	for (const resource of resources) {
		const catalogDescriptions = catalogById.get(resource.id) || new Map();
		const reference = referenceDescriptions[resource.id] || {};
		for (const exportEntry of resource.exports) {
			const name = exportEntry.name;
			const description = catalogDescriptions.has(name)
				? catalogDescriptions.get(name)
				: reference[name];
			if (!hasEnglishDescription(description)) missing++;
		}
	}
	return missing;
}

module.exports = { countMissingEnglishExportDescriptions, hasEnglishDescription };
