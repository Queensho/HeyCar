'use strict';
const fs = require('node:fs');
// Both inputs must come from migrate.js --audit on PostgreSQL of the same major version.
// Differences are structural evidence, never proof that historical DML ran.
function compareAudits(expected, actual) {
  if (!expected.schema || !actual.schema) throw new Error('AUDIT_SCHEMA_REQUIRED');
  const changes = [];
  for (const section of Object.keys(expected.schema)) {
    if (!Array.isArray(actual.schema[section])) throw new Error('AUDIT_SECTION_MISSING');
    const key = row => [row.table_name || '', row.name].join('.');
    const relevant = row => row.name !== 'schema_migrations' && row.table_name !== 'schema_migrations' && !String(row.name).startsWith('schema_migrations_');
    const wanted = new Map(expected.schema[section].filter(relevant).map(row => [key(row),row]));
    const found = new Map(actual.schema[section].filter(relevant).map(row => [key(row),row]));
    for (const [name,row] of wanted) {
      if (!found.has(name)) changes.push({section,name,status:'missing',expected:row});
      else if (JSON.stringify(row) !== JSON.stringify(found.get(name))) changes.push({section,name,status:'different',expected:row,actual:found.get(name)});
    }
    for (const [name,row] of found) if (!wanted.has(name)) changes.push({section,name,status:'extra',actual:row});
  }
  return {changes, warning:'Structural differences require review. This comparison never authorizes baseline or historical data migrations.'};
}
if (require.main === module) {
  try {
    if (process.argv.length !== 4) throw new Error('EXPECTED_AND_ACTUAL_AUDIT_PATHS_REQUIRED');
    const result = compareAudits(...process.argv.slice(2).map(file => JSON.parse(fs.readFileSync(file,'utf8'))));
    console.log(JSON.stringify(result,null,2));
    if (result.changes.length) process.exitCode = 1;
  } catch (_) { console.error('AUDIT_COMPARISON_FAILED'); process.exitCode = 2; }
}
module.exports = {compareAudits};
