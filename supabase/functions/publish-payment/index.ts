import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{...cors,'Content-Type':'application/json'}});
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
if(req.method!=='POST')return reply(405,'Método inválido');
try{
const token=req.headers.get('Authorization');if(!token)return reply(401,'Autenticação necessária');
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:token}}});
const {data:{user},error}=await db.auth.getUser();if(error||!user)return reply(401,'Sessão inválida');
const {id,path}=await req.json();if(typeof id!=='string'||typeof path!=='string'||!/^[a-f0-9-]{36}$/i.test(id)||!new RegExp('^'+id+'/[a-f0-9-]{36}\\.(png|jpg|webp)$','i').test(path))return reply(400,'Comprovante inválido');
const {data:d}=await db.from('deposits').select('*').eq('id',id).eq('employee_id',user.id).eq('status','pending').maybeSingle();if(!d)return reply(403,'Depósito indisponível');
const {data:m}=await db.from('organization_members').select('role').eq('organization_id',d.organization_id).eq('user_id',user.id).eq('status','active').maybeSingle();if(!m)return reply(403,'Acesso negado');
const {data:file,error:fe}=await db.storage.from('deposit-receipts').download(path);if(fe||!file||file.size>5242880)return reply(400,'Imagem indisponível');
const ext=path.split('.').pop();const name='comprovante.'+ext;
const hook=Deno.env.get('DISCORD_WEBHOOK_PAYMENTS');if(!hook)return reply(503,'Webhook não configurado');
const digest=await crypto.subtle.digest('SHA-256',await file.arrayBuffer());
const fingerprint=Array.from(new Uint8Array(digest),b=>b.toString(16).padStart(2,'0')).join('');
const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const {error:claim}=await admin.from('receipt_fingerprints').insert({organization_id:d.organization_id,deposit_id:id,fingerprint,storage_path:path});
if(claim){if(claim.code!=='23505')return reply(503,'Falha na verificação do comprovante');const {data:previous}=await admin.from('receipt_fingerprints').select('deposit_id,storage_path').eq('organization_id',d.organization_id).eq('fingerprint',fingerprint).maybeSingle();if(previous?.storage_path!==path)await admin.storage.from('deposit-receipts').remove([path]);return reply(409,previous?.deposit_id===id?'Comprovante já registrado neste depósito. Solicite conferência à administração.':'Comprovante duplicado: já utilizado em outro depósito.');}
const identity=user.identities?.find(i=>i.provider==='discord');
const employee=String(identity?.identity_data?.full_name||identity?.identity_data?.name||user.id).slice(0,200);
const form=new FormData();form.append('files[0]',file,name);
form.append('payload_json',JSON.stringify({username:'Underground Performance',allowed_mentions:{parse:[]},attachments:[{id:0,filename:name}],embeds:[{author:{name:'UNDERGROUND PERFORMANCE • NEW ERA CITY'},title:'💵 REGISTRO DE REPASSE',color:0xb5fa52,fields:[{name:'👤 Funcionário',value:employee},{name:'💰 Valor declarado',value:Number(d.amount).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})},{name:'📌 Situação',value:'Aguardando conferência manual'}],image:{url:'attachment://'+name},footer:{text:'Protocolo '+id},timestamp:d.created_at}]}));
const res=await fetch(hook,{method:'POST',body:form});return reply(res.ok?200:502,res.ok?'Registro e comprovante publicados':'Discord recusou o envio');
}catch{return reply(502,'Falha ao publicar comprovante')}
});