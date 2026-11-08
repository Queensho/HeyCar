// Fail closed before opening any socket. DATABASE_URL is deliberately ignored.
function testDatabaseUrl(value=process.env.TEST_DATABASE_URL) {
  if(!value)throw new Error('TEST_DATABASE_URL_REQUIRED');
  let u;try{u=new URL(value);}catch{throw new Error('UNSAFE_TEST_DATABASE_URL');}
  if(!['postgres:','postgresql:'].includes(u.protocol)||!['127.0.0.1','localhost','[::1]'].includes(u.hostname)||u.search||u.hash||!/^heycar_test_[a-z0-9_]+$/.test(decodeURIComponent(u.pathname.slice(1))))throw new Error('UNSAFE_TEST_DATABASE_URL');
  return value;
}
module.exports={testDatabaseUrl};
