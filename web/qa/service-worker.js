self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',event=>event.waitUntil(self.clients.claim()));
self.addEventListener('push',event=>event.waitUntil((async()=>{
 let p;try{p=event.data.json();}catch(_){return;}
 const url=new URL(p.url,self.location.origin),scope=new URL(self.registration.scope);
 if(url.origin!==self.location.origin||url.pathname!==scope.pathname)return;
 await self.registration.showNotification(String(p.title||'CepQontag'),{body:String(p.body||''),tag:p.tag,data:{url:url.href,bookingId:p.data?.bookingId},icon:scope.pathname+'icons/Icon-192.png'});
})()));
self.addEventListener('notificationclick',event=>{event.notification.close();event.waitUntil((async()=>{
 const url=new URL(event.notification.data.url),scope=new URL(self.registration.scope);
 if(url.origin!==self.location.origin||url.pathname!==scope.pathname)return;
 await self.clients.openWindow(url.href);
})());});
