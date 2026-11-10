/* Dedicated staging Web Push. No production config, service-account or token persistence. */
(()=>{
 const origin='https://staging-api-185-165-46-213.nip.io';
 function guard(role){if(location.origin!==origin||!['owner','business'].includes(role))throw Error('QA_ORIGIN_REQUIRED');}
 function device(role){const key='cepqontag_qa_push_device_'+role;let id=localStorage.getItem(key);if(!id){id=crypto.randomUUID();localStorage.setItem(key,id);}return id;}
 const api=(path,token,options={})=>fetch(origin+'/api/qa/services-v2/push/'+path,{...options,headers:{'Content-Type':'application/json',Authorization:'Bearer '+token}});
 window.cepqontagQaEnableWebPush=async(token,role)=>{
  guard(role);if(!('serviceWorker' in navigator)||!('PushManager' in window))throw Error('WEB_PUSH_UNSUPPORTED');
  const configResponse=await api('config',token);if(!configResponse.ok)throw Error('QA_ACCOUNT_REQUIRED');const config=await configResponse.json();
  if(config.recipientRole!==role||!config.webPush.enabled)throw Error('QA_WEB_PUSH_NOT_CONFIGURED');
  if(await Notification.requestPermission()!=='granted')throw Error('NOTIFICATION_PERMISSION_REQUIRED');
  const scope=role==='business'?'/car-wash-business/':'/car-wash-owner/';
  const registration=await navigator.serviceWorker.register(scope+'qa-service-worker.js',{scope});
  await new Promise((resolve,reject)=>{if(registration.active)return resolve();const worker=registration.installing||registration.waiting;if(!worker)return reject(Error('WORKER_NOT_READY'));worker.addEventListener('statechange',()=>{if(worker.state==='activated')resolve();else if(worker.state==='redundant')reject(Error('WORKER_INSTALL_FAILED'));});});
  const key=config.webPush.publicKey.replace(/-/g,'+').replace(/_/g,'/');const applicationServerKey=Uint8Array.from(atob(key+'='.repeat((4-key.length%4)%4)),c=>c.charCodeAt(0));
  let subscription=await registration.pushManager.getSubscription();
  if(subscription){await subscription.unsubscribe();subscription=null;}
  subscription=await registration.pushManager.subscribe({userVisibleOnly:true,applicationServerKey});
  const response=await api('devices',token,{method:'POST',body:JSON.stringify({channel:'web',deviceId:device(role),subscription:subscription.toJSON()})});
  if(!response.ok){await subscription.unsubscribe();throw Error('QA_SUBSCRIPTION_REFUSED');}return true;
 };
 window.cepqontagQaDisableWebPush=async(token,role)=>{
  guard(role);await api('devices?deviceId='+encodeURIComponent(device(role)),token,{method:'DELETE'});
  const registration=await navigator.serviceWorker.getRegistration(role==='business'?'/car-wash-business/':'/car-wash-owner/');const subscription=await registration?.pushManager.getSubscription();if(subscription)await subscription.unsubscribe();
 };
})();
