import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{...cors,'Content-Type':'application/json'}});
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
if(req.method!=='POST')return reply(405,'Método inválido');
try{
const token=req.headers.get('Authorization');if(!token)return reply(401,'Sessão necessária');
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:token}}});
const {data:{user}}=await db.auth.getUser();if(!user)return reply(401,'Sessão inválida');
const form=await req.formData();const org=String(form.get('org')),region=String(form.get('region')),quantity=Number(form.get('quantity')),notes=String(form.get('notes')||'').slice(0,500),file=form.get('receipt');
if(!['Sul','Norte'].includes(region)||!Number.isInteger(quantity)||quantity<1||quantity>100||!(file instanceof File)||file.size<1||file.size>5242880||!['image/png','image/jpeg','image/webp'].includes(file.type))return reply(400,'Região, quantidade ou print inválido');
const access=await db.rpc('farm_access',{p_org:org,p_admin:false});if(access.error||!access.data)return reply(403,'Acesso negado');
const hook=Deno.env.get('DISCORD_WEBHOOK_TOWING');if(!hook)return reply(503,'Webhook de reboques não configurado');
const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',await file.arrayBuffer())),b=>b.toString(16).padStart(2,'0')).join('');
const saved=await admin.from('towing_entries').insert({organization_id:org,employee_id:user.id,quantity,notes,region,receipt_hash:hash}).select('id,created_at').single();
if(saved.error)return reply(409,saved.error.code==='23505'?'Print já registrado. Consulte o histórico.':'Não foi possível registrar');
const id=saved.data.id, total=quantity*(region==='Sul'?30000:50000),money=(n:number)=>n.toLocaleString('pt-BR',{style:'currency',currency:'BRL'});
const identity=user.identities?.find(i=>i.provider==='discord');const employee=String(identity?.identity_data?.full_name||identity?.identity_data?.name||user.id).slice(0,200);
const name='comprovante.'+({'image/png':'png','image/jpeg':'jpg','image/webp':'webp'}[file.type]||'png');
const payload=new FormData();payload.append('files[0]',file,name);payload.append('payload_json',JSON.stringify({username:'Underground Performance',allowed_mentions:{parse:[]},attachments:[{id:0,filename:name}],embeds:[{title:'🚗 REGISTRO DE REBOQUE',color:0xb5fa52,fields:[{name:'Funcionário',value:employee},{name:'Região / Quantidade',value:region+' / '+quantity},{name:'Valor',value:money(total)},{name:'Repasse à mecânica (15%)',value:money(total*0.15)},{name:'Observação',value:notes||'—'}],image:{url:'attachment://'+name},footer:{text:'Protocolo '+id+' • Print sujeito a conferência'},timestamp:saved.data.created_at}]}));
const url=new URL(hook);url.searchParams.set('wait','true');const sent=await fetch(url,{method:'POST',body:payload});if(!sent.ok)return reply(502,'Registro salvo, Discord recusou o envio. Contate a administração.');
const result=await sent.json();const linked=await admin.from('towing_entries').update({discord_message_id:result.id}).eq('id',id);if(linked.error)return reply(502,'Publicado, mas vínculo não salvo. Contate a administração.');
return reply(200,'Reboque registrado e publicado no Discord');
}catch{return reply(502,'Falha no envio. Confira o histórico antes de tentar novamente.')}
});