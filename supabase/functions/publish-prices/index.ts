import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{...cors,'Content-Type':'application/json'}});
if(req.method!=='POST')return reply(405,'Método inválido');
const token=req.headers.get('Authorization');if(!token)return reply(401,'Autenticação necessária');
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:token}}});
const {data:{user},error}=await db.auth.getUser();if(error||!user)return reply(401,'Sessão inválida');
const {data:org}=await db.from('organizations').select('id').eq('slug','new-era-city').maybeSingle();if(!org)return reply(403,'Organização indisponível');
const {data:m}=await db.from('organization_members').select('role').eq('organization_id',org.id).eq('user_id',user.id).eq('status','active').maybeSingle();if(m?.role!=='proprietario')return reply(403,'Apenas proprietário');
const {data:p,error:e}=await db.from('products').select('name,category,price_min,price_max').eq('organization_id',org.id).eq('active',true).order('category').order('name');if(e||!p?.length)return reply(409,'Catálogo indisponível');
const money=(n:number)=>Number(n).toLocaleString('pt-BR',{style:'currency',currency:'BRL'});
const lines=p.map(x=>x.category+' • '+x.name+' — '+money(x.price_min)+(Number(x.price_max)!==Number(x.price_min)?' a '+money(x.price_max):''));
const description=lines.join('\n');if(description.length>4096)return reply(413,'Catálogo excede limite de publicação');
const hook=Deno.env.get('DISCORD_WEBHOOK_PRICES');if(!hook)return reply(503,'Webhook não configurado');
try{const res=await fetch(hook,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({allowed_mentions:{parse:[]},embeds:[{title:'📈 TABELA OFICIAL | UNDERGROUND PERFORMANCE',description,color:0x22c55e,footer:{text:'New Era City • Valores do RP'},timestamp:new Date().toISOString()}]})});return reply(res.ok?200:502,res.ok?'Tabela publicada':'Discord recusou o envio')}catch{return reply(502,'Falha de comunicação')}
});