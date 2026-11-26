import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{...cors,'Content-Type':'application/json'}});
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
if(req.method!=='POST')return reply(405,'Método inválido');
try{
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const {data:{user}}=await db.auth.getUser(req.headers.get('Authorization')?.replace(/^Bearer /i,'')||'');if(!user)return reply(401,'Sessão inválida');
const {id}=await req.json();if(typeof id!=='string'||!/^[a-f0-9-]{36}$/i.test(id))return reply(400,'Protocolo inválido');
const {data:d}=await db.from('deposits').select('*').eq('id',id).maybeSingle();if(!d)return reply(404,'Depósito indisponível');
const {data:m}=await db.from('organization_members').select('role,status,manual_block,discord_verified_until').eq('organization_id',d.organization_id).eq('user_id',user.id).maybeSingle();
if(!m||m.status!=='active'||m.manual_block||!['proprietario','gerente'].includes(m.role)||!(Date.parse(m.discord_verified_until||'')>Date.now()))return reply(403,'Acesso negado');
if(!['approved','rejected'].includes(d.status))return reply(409,'Depósito ainda pendente');
const {data:link}=await db.from('payment_messages').select('message_id').eq('deposit_id',id).maybeSingle();if(!link)return reply(404,'Mensagem antiga sem vínculo');
const hook=Deno.env.get('DISCORD_WEBHOOK_PAYMENTS');if(!hook)return reply(503,'Webhook não configurado');
const url=new URL(hook);url.pathname=url.pathname.replace(/\/$/,'')+'/messages/'+link.message_id;url.searchParams.delete('wait');
const original=await fetch(url);if(!original.ok)return reply(502,'Mensagem original indisponível');
const message=await original.json();const embed=message.embeds?.[0];if(!embed||embed.footer?.text!=='Protocolo '+id)return reply(409,'Protocolo da mensagem incompatível');
const approved=d.status==='approved';const fields=(embed.fields||[]).filter((f:{name:string})=>!['📌 Situação','Motivo da rejeição'].includes(f.name));fields.push({name:'📌 Situação',value:approved?'✅ APROVADO':'❌ REJEITADO'});if(!approved&&d.reason)fields.push({name:'Motivo da rejeição',value:String(d.reason).slice(0,1024)});
const attachments=(message.attachments||[]) as {id:string;filename:string;url:string}[];
const receipt=attachments.find(x=>x.url.split('?')[0]===String(embed.image?.url||'').split('?')[0])||attachments.find(x=>/^comprovante\.(png|jpg|webp)$/i.test(x.filename));
const result=await fetch(url,{method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({allowed_mentions:{parse:[]},embeds:[{author:embed.author,title:embed.title,color:approved?0x57f287:0xed4245,fields,image:receipt?{url:'attachment://'+receipt.filename}:embed.image?.url?{url:embed.image.url}:undefined,footer:embed.footer,timestamp:embed.timestamp}]})});
return reply(result.ok?200:502,result.ok?'Status atualizado no Discord':'Falha ao editar mensagem');
}catch{return reply(502,'Falha de sincronização')}
});