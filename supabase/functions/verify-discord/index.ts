import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
// Cargos superiores ao proprietario: usam as permissoes administrativas existentes.
const roles=[['1550667825058816130','proprietario'],['1550668167360024576','proprietario'],['1550614148860092497','proprietario'],['1550614148822335587','gerente'],['1550614148822335586','supervisor'],['1550614148822335585','mecanico'],['1550614148822335584','mecanico'],['1550695303953387520','mecanico'],['1550614148822335583','mecanico'],['1550614148822335581','aprendiz'],['1550614148822335582','aprendiz']];
Deno.serve(async req=>{
const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
if(req.method==='OPTIONS')return new Response(null,{headers:cors});
if(req.method!=='POST')return reply({},405);
try{
const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const {data:{user}}=await db.auth.getUser(req.headers.get('Authorization')?.replace(/^Bearer /i,'')||'');
if(!user)return reply({error:'Sessão inválida'},401);
const {token}=await req.json();
const identity=user.identities?.find(i=>i.provider==='discord');
if(!identity||typeof token!=='string')return reply({error:'Entre novamente pelo Discord'},403);
const allowedMembership=async()=>{const {data:org}=await db.from('organizations').select('id').eq('slug','new-era-city').single();if(!org)return false;const {data:m,error}=await db.from('organization_members').select('status,discord_verified_until,manual_block').eq('organization_id',org.id).eq('user_id',user.id).maybeSingle();return !error&&m?.status==='active'&&!m.manual_block&&Date.parse(m.discord_verified_until||'')>Date.now()};
const headers={Authorization:'Bearer '+token};
const me=await fetch('https://discord.com/api/v10/users/@me',{headers});
if(!me.ok)return reply({error:'Autorização Discord expirada'},403);
const account=await me.json();
if(account.id!==identity.identity_data?.sub && account.id!==identity.identity_data?.provider_id && account.id!==identity.id)return reply({error:'Conta Discord incompatível'},403);
if(Deno.env.get('SUPABASE_URL')==='https://iafiorzdockmlgauwtjl.supabase.co' && account.id===Deno.env.get('DEV_ADMIN_DISCORD_ID') && account.id==='1174745079630549014'){
const {error}=await db.rpc('sync_discord_membership',{p_user:user.id,p_discord:account.id,p_name:account.global_name||account.username,p_role:'proprietario'});
if(error)return reply({error:'Falha ao sincronizar acesso DEV'},500);
return reply({allowed:await allowedMembership(),role:'proprietario',discord_id:account.id,name:account.global_name||account.username});
}
const member=await fetch('https://discord.com/api/v10/users/@me/guilds/1550614148822335578/member',{headers});
if(!member.ok && member.status!==404)return reply({error:'Não foi possível verificar o Discord'},503);
const data=member.ok?await member.json():{roles:[]};
const role=roles.find(([id])=>data.roles?.includes(id))?.[1];
const {error}=await db.rpc('sync_discord_membership',{p_user:user.id,p_discord:account.id,p_name:account.global_name||account.username,p_role:role||null});
if(error)return reply({error:'Falha ao sincronizar acesso'},500);
return reply({allowed:!!role&&await allowedMembership(),role,discord_id:account.id,name:account.global_name||account.username});
}catch{return reply({error:'Falha na verificação'},500)}
});
