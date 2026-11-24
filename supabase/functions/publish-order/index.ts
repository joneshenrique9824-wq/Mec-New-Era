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
const {id}=await req.json();if(typeof id!=='string'||!/^[0-9a-f-]{36}$/i.test(id))return reply(400,'Protocolo inválido');
const {data:o}=await db.from('service_orders').select('*').eq('id',id).eq('employee_id',user.id).maybeSingle();if(!o)return reply(404,'Atendimento indisponível');
const {data:m}=await db.from('organization_members').select('role,discord_verified_until').eq('organization_id',o.organization_id).eq('user_id',user.id).eq('status','active').maybeSingle();if(!m||Date.parse(m.discord_verified_until||'')<=Date.now()||!m.discord_verified_until)return reply(403,'Acesso expirado');
const {data:p}=await db.from('profiles').select('character_name,discord_id').eq('id',user.id).maybeSingle();
const {data:s,error:e}=await db.from('sales').select('product_name,quantity,total,mechanic_share,employee_share').eq('service_order_id',id).eq('employee_id',user.id).eq('organization_id',o.organization_id);if(e||!s?.length)return reply(409,'Serviços indisponíveis');
const money=(n:number)=>Number(n).toLocaleString('pt-BR',{style:'currency',currency:'BRL'});
const total=(k:'total'|'mechanic_share'|'employee_share')=>money(s.reduce((a,x)=>a+Number(x[k]),0));
const description=s.map(x=>x.quantity+'x '+x.product_name+' — '+money(x.total)).join('\n');if(description.length>4000)return reply(413,'Registro muito extenso');
const hook=Deno.env.get('DISCORD_WEBHOOK_URL');if(!hook)return reply(503,'Webhook não configurado');
const res=await fetch(hook,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({allowed_mentions:{parse:[]},embeds:[{author:{name:'UNDERGROUND PERFORMANCE • NEW ERA CITY'},title:'🧾 REGISTRO DE ATENDIMENTO',url:'https://undergrounddev.vercel.app',description:'**SERVIÇOS REALIZADOS**\n'+description,color:0xb5fa52,fields:[{name:'👤 Funcionário',value:String(p?.character_name||user.id).slice(0,200)},{name:'👥 Cliente',value:String(o.customer||'Não informado').slice(0,200)},{name:'💵 Total',value:total('total'),inline:true},{name:'🏢 Oficina • 15%',value:total('mechanic_share'),inline:true},{name:'💰 Funcionário • 85%',value:total('employee_share'),inline:true},{name:'Observações',value:String(o.notes||'Sem observações').slice(0,500)},{name:'📌 Situação do repasse',value:'Comissão registrada; transferência ainda sujeita a conferência.'}],footer:{text:'Protocolo '+id},timestamp:o.created_at}]})});return reply(res.ok?200:502,res.ok?'Registro publicado':'Discord recusou o envio');
}catch{return reply(502,'Falha ao publicar registro')}
});