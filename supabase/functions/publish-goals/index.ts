import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(status:number,message:string)=>new Response(JSON.stringify({message}),{status,headers:{...cors,'Content-Type':'application/json'}});
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
if(req.method!=='POST')return reply(405,'Método inválido');
try{
const token=req.headers.get('Authorization');if(!token)return reply(401,'Autenticação necessária');
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:token}}});
const {data:{user}}=await db.auth.getUser();if(!user)return reply(401,'Sessão inválida');
const {data:org}=await db.from('organizations').select('id').eq('slug','new-era-city').maybeSingle();if(!org)return reply(403,'Organização indisponível');
const {data:m}=await db.from('organization_members').select('role,discord_verified_until').eq('organization_id',org.id).eq('user_id',user.id).eq('status','active').maybeSingle();
if(m?.role!=='proprietario'||!m.discord_verified_until||Date.parse(m.discord_verified_until)<=Date.now())return reply(403,'Acesso restrito');
const {data:g,error}=await db.rpc('goal_ranking',{p_org:org.id,p_period:'day'});if(error||!g)return reply(503,'Metas indisponíveis');
const money=(n:number)=>Number(n).toLocaleString('pt-BR',{style:'currency',currency:'BRL'});
const ranking=(g.ranking||[]).slice(0,10).map((x:{name:string;total:number;sales:number},i:number)=>(i+1)+'. '+String(x.name).slice(0,60)+' — '+money(x.total)).join('\n');
const date=new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo'}).format(new Date());
const hook=Deno.env.get('DISCORD_WEBHOOK_GOALS');if(!hook)return reply(503,'Webhook não configurado');
const res=await fetch(hook,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:'Underground Performance',allowed_mentions:{parse:[]},embeds:[{author:{name:'UNDERGROUND PERFORMANCE • NEW ERA CITY'},title:'💼 METAS E DESEMPENHO DIÁRIO',url:'https://undergrounddev.vercel.app',color:0xb5fa52,description:'**Relatório de '+date+'**',fields:[{name:'🎯 Meta individual',value:g.target?money(g.target):'Não definida',inline:true},{name:'💰 Faturamento da equipe',value:money(g.team_today),inline:true},{name:'🏢 Comissão estimada (15%)',value:money(Number(g.team_today)*.15),inline:true},{name:'🏆 Ranking do dia',value:ranking||'Nenhuma venda registrada'}],footer:{text:'CENTRAL OPERACIONAL • Horário de Brasília • Valores do RP'},timestamp:new Date().toISOString()}]})});
return reply(res.ok?200:502,res.ok?'Metas publicadas':'Discord recusou o envio');
}catch{return reply(502,'Falha ao publicar metas')}
});