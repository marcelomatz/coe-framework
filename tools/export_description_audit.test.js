'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { countMissingEnglishExportDescriptions, hasEnglishDescription } = require('./export_description_audit.js');

test('counts a usable complementary reference translation as present', () => {
	const resources = [{ id: 'resource', exports: [{ name: 'Translated' }, { name: 'Missing' }] }];
	const catalog = [{ id: 'resource', exports: [] }];
	const reference = { resource: { Translated: 'Returns the translated result.' } };

	assert.equal(countMissingEnglishExportDescriptions(resources, catalog, reference), 1);
});

test('does not count missing, blank, or generic descriptions as translations', () => {
	const resources = [{
		id: 'resource',
		exports: [{ name: 'Missing' }, { name: 'Blank' }, { name: 'Generic' }],
	}];
	const catalog = [{ id: 'resource', exports: [
		{ name: 'Blank', desc: '  ' },
		{ name: 'Generic', desc: 'No description available.' },
	] }];

	assert.equal(countMissingEnglishExportDescriptions(resources, catalog, {}), 3);
	assert.equal(hasEnglishDescription('A specific English description.'), true);
	assert.equal(hasEnglishDescription('TBD'), false);
});

test('uses the catalog description before its complementary reference entry', () => {
	const resources = [{ id: 'resource', exports: [{ name: 'Export' }] }];
	const catalog = [{ id: 'resource', exports: [{ name: 'Export', desc: '' }] }];
	const reference = { resource: { Export: 'A valid complementary description.' } };

	assert.equal(countMissingEnglishExportDescriptions(resources, catalog, reference), 1);
});
