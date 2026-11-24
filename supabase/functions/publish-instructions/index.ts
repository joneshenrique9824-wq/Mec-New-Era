import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
const headers={...cors,'Content-Type':'application/json'};
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers});
if(req.method!=='POST')return reply(405,'Método inválido');
const token=req.headers.get('Authorization');if(!token)return reply(401,'Autenticação necessária');
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:token}}});
const {data:{user},error}=await db.auth.getUser();if(error||!user)return reply(401,'Sessão inválida');
const {data:org}=await db.from('organizations').select('id').eq('slug','new-era-city').maybeSingle();
if(!org)return reply(403,'Organização indisponível');
const {data:member}=await db.from('organization_members').select('role').eq('organization_id',org.id).eq('user_id',user.id).eq('status','active').maybeSingle();
if(!member||member.role!=='proprietario')return reply(403,'Apenas proprietário');
const hook=Deno.env.get('DISCORD_WEBHOOK_INSTRUCTIONS');if(!hook)return reply(503,'Webhook não configurado');
try{const response=await fetch(hook,{method:'POST',headers,body:JSON.stringify({allowed_mentions:{parse:[]},username:'Underground Performance',embeds:[{author:{name:'UNDERGROUND PERFORMANCE • NEW ERA CITY'},title:'📘 CENTRAL DE INSTRUÇÕES',url:'https://undergrounddev.vercel.app',color:0xb5fa52,description:'**Bem-vindo à central operacional da oficina.**\nAcesse o sistema pelo título acima e siga as etapas abaixo.',fields:[{name:'🔐 01 • Acesso',value:'Entre com sua conta Discord autorizada.'},{name:'🔧 02 • Orçamento',value:'Informe o cliente, selecione os serviços e confira quantidades e valores.'},{name:'🏎️ 03 • Full Tuning',value:'Motor, turbo, transmissão, suspensão completa e freios. Blindagem à parte.'},{name:'📦 04 • Kits e pneus',value:'Informe as quantidades vendidas ou aplicadas na calculadora.'},{name:'🧾 05 • Finalização',value:'Finalize somente atendimentos realizados e pagos. Envie o registro ao Discord.'},{name:'💰 06 • Divisão financeira',value:'**15%** para a oficina • **85%** para o funcionário.'},{name:'📸 07 • Repasse',value:'Acumule comissões, transfira ao painel, registre o depósito e anexe o print. Aguarde conferência.'},{name:'📊 08 • Desempenho',value:'Consulte metas, ranking e carteira no sistema.'},{name:'⚠️ Regras',value:'Não duplique registros ou comprovantes. Todos os valores são do RP.'}],footer:{text:'CENTRAL OPERACIONAL • Manual do funcionário'},timestamp:new Date().toISOString()}]})});return reply(response.ok?200:502,response.ok?'Manual publicado':'Discord recusou o envio')}catch{return reply(502,'Falha de comunicação com Discord')}
});