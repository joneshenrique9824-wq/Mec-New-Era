import React,{useState,useEffect} from 'react';
import {createRoot} from 'react-dom/client';
import {createClient} from '@supabase/supabase-js';
import './style.css';
const url=import.meta.env.VITE_SUPABASE_URL,key=import.meta.env.VITE_SUPABASE_ANON_KEY;
const db=url&&key?createClient(url,key):null;
function App(){
const [email,E]=useState(''),[password,P]=useState(''),[message,M]=useState(''),[user,U]=useState(''),[busy,B]=useState(false);
useEffect(()=>{if(!db)return;const {data}=db.auth.onAuthStateChange((_,s)=>U(s?.user.email??s?.user.id??''));return ()=>data.subscription.unsubscribe()},[]);
async function login(e:React.FormEvent){e.preventDefault();if(!db)return;B(true);try{const {error}=await db.auth.signInWithPassword({email,password});M(error?error.message:'');}catch{M('Falha de conexão.')}finally{B(false)}}
return <main><header>NEW ERA CITY <small> MECÂNICA CONTROL PRO</small></header><section><h1>{user?'Área do funcionário':'Acesso ao sistema'}</h1>{!db?<p>Configure o Supabase no arquivo .env para habilitar o acesso.</p>:user?<><p>Sessão autenticada. Os módulos financeiros ainda estão em desenvolvimento.</p><button onClick={()=>db.auth.signOut()}>Sair</button></>:<form onSubmit={login}><label>E-mail<input type="email" required value={email} onChange={e=>E(e.target.value)}/></label><label>Senha<input type="password" required value={password} onChange={e=>P(e.target.value)}/></label><button disabled={busy}>Entrar</button><button type="button" onClick={async()=>{const {error}=await db.auth.signInWithOAuth({provider:'discord',options:{redirectTo:location.origin}});if(error)M(error.message)}}>Entrar com Discord</button></form>}<p role="status">{message}</p></section><footer>Ambiente de RP • Base inicial em desenvolvimento</footer></main>}
createRoot(document.getElementById('root')!).render(<App/>);