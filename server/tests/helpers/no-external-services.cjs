// Loaded only by the integration-test subprocess. Any accidental external HTTP
// call fails the test process instead of reaching a real provider.
const originalFetch=global.fetch;
global.fetch=(input,...args)=>{
 const url=new URL(typeof input==='string'?input:input.url||input);
 if(!['127.0.0.1','localhost','[::1]'].includes(url.hostname))throw new Error('External HTTP forbidden in isolated tests');
 return originalFetch(input,...args);
};
require('node:https').request=()=>{throw new Error('External HTTPS forbidden in isolated tests');};
require('web-push').sendNotification=()=>{throw new Error('Real Web Push forbidden in isolated tests');};
