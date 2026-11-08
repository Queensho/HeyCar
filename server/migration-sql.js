// Keep transaction ownership in the runner, including legacy files with a
// COMMIT before their last DDL statement. Never rewrite migration checksums.
function migrationBody(sql) {
  let start=0, command='', quote='', dollar='', line=false, depth=0, escapeString=false;
  const removed=[];
  for(let i=0;i<sql.length;i++) {
    const c=sql[i], next=sql[i+1];
    if(line){if(c==='\n')line=false;continue;}
    if(depth){if(c==='/'&&next==='*'){depth++;i++;}else if(c==='*'&&next==='/'){depth--;i++;}continue;}
    if(dollar){if(sql.startsWith(dollar,i)){i+=dollar.length-1;dollar='';}continue;}
    if(quote){if(c===quote){if(next===quote)i++;else quote='';}else if(c==='\\'&&quote==="'"&&escapeString)i++;continue;}
    if(c==='-'&&next==='-'){line=true;i++;continue;}
    if(c==='/'&&next==='*'){depth=1;i++;continue;}
    if(c==="'"||c==='"'){escapeString=c==="'"&&/\bE$/i.test(command);quote=c;command+=' ? ';continue;}
    if(c==='$'){const match=sql.slice(i).match(/^\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$/);if(match){dollar=match[0];command+=' ? ';i+=dollar.length-1;continue;}}
    if(c===';'){
      const text=command.trim().toUpperCase();
      if(/^(?:BEGIN(?:\s+(?:WORK|TRANSACTION))?|COMMIT(?:\s+(?:WORK|TRANSACTION))?)$/.test(text))removed.push([start,i+1]);
      else if(/^(?:BEGIN|COMMIT|ROLLBACK|ABORT|START\s+TRANSACTION|END|SAVEPOINT|RELEASE|PREPARE\s+TRANSACTION)\b/.test(text))throw new Error('UNSUPPORTED_MIGRATION_TRANSACTION');
      start=i+1;command='';
    }else command+=c;
  }
  if(quote||dollar||depth)throw new Error('UNTERMINATED_MIGRATION_SQL');
  if(/^(BEGIN|COMMIT|ROLLBACK)$/i.test(command.trim()))throw new Error('UNTERMINATED_MIGRATION_TRANSACTION');
  let result='',cursor=0;
  for(const [from,to] of removed){result+=sql.slice(cursor,from);cursor=to;}
  return result+sql.slice(cursor);
}
module.exports={migrationBody};
