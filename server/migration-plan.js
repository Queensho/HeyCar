'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const checksum = text => crypto.createHash('sha256').update(text).digest('hex');

// Split only at SQL-level semicolons; DO bodies, strings and comments are opaque.
function statements(sql) {
  const result = [];
  let start = 0, i = 0, quote = '', block = 0, line = false;
  while (i < sql.length) {
    const c = sql[i], next = sql[i + 1];
    if (line) { if (c === '\n') line = false; i++; continue; }
    if (block) {
      if (c === '/' && next === '*') { block++; i += 2; }
      else if (c === '*' && next === '/') { block--; i += 2; }
      else i++;
      continue;
    }
    if (quote) {
      if (sql.startsWith(quote, i)) {
        if (quote.length === 1 && sql[i + 1] === quote) { i += 2; continue; }
        i += quote.length; quote = ''; continue;
      }
      // Backslash escapes in E'...' strings are handled conservatively too.
      if (c === '\\' && quote === "'") { i += 2; continue; }
      i++; continue;
    }
    if (c === '-' && next === '-') { line = true; i += 2; continue; }
    if (c === '/' && next === '*') { block = 1; i += 2; continue; }
    if (c === "'" || c === '"') { quote = c; i++; continue; }
    const dollar = c === '$' && sql.slice(i).match(/^\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$/);
    if (dollar) { quote = dollar[0]; i += quote.length; continue; }
    if (c === ';') { result.push(sql.slice(start, ++i)); start = i; }
    else i++;
  }
  if (quote || block) throw new Error('MIGRATION_UNTERMINATED_SQL');
  if (sql.slice(start).trim()) result.push(sql.slice(start));
  return result;
}
function command(statement) {
  let i = 0;
  while (i < statement.length) {
    if (/\s/.test(statement[i])) { i++; continue; }
    if (statement.startsWith('--', i)) {
      const end = statement.indexOf('\n', i);
      i = end < 0 ? statement.length : end + 1;
      continue;
    }
    if (statement.startsWith('/*', i)) {
      let depth = 1;
      i += 2;
      while (depth && i < statement.length) {
        if (statement.startsWith('/*', i)) { depth++; i += 2; }
        else if (statement.startsWith('*/', i)) { depth--; i += 2; }
        else i++;
      }
      continue;
    }
    break;
  }
  return statement.slice(i).replace(/;\s*$/, '').trim();
}
function executableSql(sql) {
  const parts = statements(sql);
  const meaningful = parts.map((text, index) => ({text, index, cmd: command(text)})).filter(x => x.cmd);
  let open = false;
  for (const part of meaningful) {
    if (/^(BEGIN|START\s+TRANSACTION)$/i.test(part.cmd)) {
      if (open) throw new Error('MIGRATION_TRANSACTION_WRAPPER_INVALID');
      open = true;
      parts[part.index] = '';
    } else if (/^(COMMIT|END)$/i.test(part.cmd)) {
      if (!open) throw new Error('MIGRATION_TRANSACTION_WRAPPER_INVALID');
      open = false;
      parts[part.index] = '';
    } else if (/^(BEGIN|START\s+TRANSACTION|COMMIT|END|ROLLBACK|ABORT|SAVEPOINT|RELEASE|PREPARE\s+TRANSACTION|SET\s+(?:LOCAL\s+)?TRANSACTION)\b/i.test(part.cmd)) {
      throw new Error('MIGRATION_EMBEDDED_TRANSACTION_CONTROL');
    }
  }
  if (open) throw new Error('MIGRATION_TRANSACTION_WRAPPER_INVALID');
  return parts.join('\n');
}
function migrationFiles(dir = path.join(__dirname, 'migrations')) {
  const names = fs.readdirSync(dir).filter(name => name.endsWith('.sql')).sort();
  if (names.some(name => !/^\d{3}_.+\.sql$/.test(name))) throw new Error('MIGRATION_FILENAME_INVALID');
  return names.map(name => {
    const sql = fs.readFileSync(path.join(dir, name), 'utf8');
    return {name, sql, sha256: checksum(sql), executable: executableSql(sql)};
  });
}
function migrationPlan(files, rows) {
  const known = new Map(rows.map(row => [row.filename, String(row.checksum_sha256).trim()]));
  const names = new Set(files.map(file => file.name));
  for (const name of known.keys()) if (!names.has(name)) throw new Error(`MIGRATION_UNKNOWN_TRACKED_FILE: ${name}`);
  return files.map(file => {
    if (known.has(file.name) && known.get(file.name) !== file.sha256) throw new Error(`MIGRATION_CHECKSUM_MISMATCH: ${file.name}`);
    return {filename: file.name, checksum_sha256: file.sha256, status: known.has(file.name) ? 'tracked' : 'untracked_requires_verification'};
  });
}
module.exports = {checksum, statements, executableSql, migrationFiles, migrationPlan};
