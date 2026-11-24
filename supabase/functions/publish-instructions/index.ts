import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
Deno.serve(async req=>{
const headers={'Content-Type':'application/json'};
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
try{const response=await fetch(hook,{method:'POST',headers,body:JSON.stringify({allowed_mentions:{parse:[]},embeds:[{title:'📄 MANUAL | UNDERGROUND PERFORMANCE',color:0x22c55e,description:'New Era City • Instruções de utilização',fields:[{name:'1. Acesso',value:'Entre com sua conta autorizada.'},{name:'2. Orçamentos',value:'Selecione serviços, quantidades e confira o total. Copie ou imprima o orçamento.'},{name:'3. Vendas',value:'Registre cada venda realizada com o valor correto.'},{name:'4. Carteira',value:'Acompanhe a comissão de 15% da mecânica e registre depósitos realizados no jogo.'},{name:'5. Conferência',value:'Guarde o print original do pagamento. Aguarde a aprovação da administração.'},{name:'6. Regras',value:'Não duplique registros. Informe divergências à gerência. Todos os valores são fictícios do RP.'}],footer:{text:'Underground Performance • New Era City'}}]})});return reply(response.ok?200:502,response.ok?'Manual publicado':'Discord recusou o envio')}catch{return reply(502,'Falha de comunicação com Discord')}
});