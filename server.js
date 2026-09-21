import http from "http";
import fs from "fs";
import path from "path";
import crypto from "crypto";
import { URL } from "url";

const PORT = Number(process.env.PORT || 10000);
const HOST = "0.0.0.0";
const BRIDGE_TOKEN = process.env.BRIDGE_CONNECT_PASSWORD || "";
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-3.6-flash";
const PUBLIC_DIR = process.cwd();
const queue = [];
const results = new Map();
const chats = new Map();

function send(res, code, data, type="application/json; charset=utf-8") {
  const body = typeof data === "string" ? data : JSON.stringify(data);
  res.writeHead(code, {
    "Content-Type": type,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, X-Bridge-Token",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
  });
  res.end(body);
}
function bridgeAuth(req){ return !!BRIDGE_TOKEN && req.headers["x-bridge-token"] === BRIDGE_TOKEN; }
async function readBody(req){ let s=""; for await(const c of req)s+=c; return s?JSON.parse(s):{}; }

function fallback(text){
  const ops=[];
  if(/(منصة|platform|part|بلوك|قطعة)/i.test(text)){
    const m=text.match(/(\d+(?:\.\d+)?)\s*(?:x|×|في)\s*(\d+(?:\.\d+)?)/i);
    ops.push({type:"CREATE_PART",name:"HaroonPart",parent:"Workspace",properties:{
      Size:[Number(m?.[1]||20),2,Number(m?.[2]||20)],Position:[0,1,0],Anchored:true,Material:"SmoothPlastic"
    }});
  }
  if(/(مجلد|folder)/i.test(text))ops.push({type:"CREATE_FOLDER",name:"HaroonFolder",parent:"Workspace"});
  if(/(احذف|حذف|delete)/i.test(text))ops.push({type:"DELETE",name:"HaroonPart"});
  return {reply:ops.length?"تم تجهيز أوامر التنفيذ وإرسالها للماب.":"لم أجد عملية بناء واضحة. جرّب: اصنع منصة 20 في 20",operations:ops};
}
async function plan(text,history){
  if(!GEMINI_API_KEY)return fallback(text);
  const prompt=`Convert this Roblox Studio Lite build request into safe JSON only.
Schema: {"reply":"Arabic response","operations":[{"type":"CREATE_PART|CREATE_FOLDER|DELETE|MOVE|RESIZE|SET_PROPERTY|RENAME","name":"...","parent":"Workspace","properties":{}}]}
For CREATE_PART Size and Position are [x,y,z]. Never output arbitrary code.
Request: ${text}
History: ${JSON.stringify(history?.slice(-10)||[])}`;
  const r=await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent`,{
    method:"POST",headers:{"Content-Type":"application/json","x-goog-api-key":GEMINI_API_KEY},
    body:JSON.stringify({contents:[{role:"user",parts:[{text:prompt}]}],generationConfig:{responseMimeType:"application/json",temperature:0.15}})
  });
  if(!r.ok)throw Error("AI provider HTTP "+r.status);
  const d=await r.json(), raw=d?.candidates?.[0]?.content?.parts?.[0]?.text;
  if(!raw)throw Error("AI returned no plan");
  return JSON.parse(raw);
}
function serve(res,urlPath){
  const file=urlPath==="/"?"index.html":urlPath.replace(/^\/+/,"");
  const target=path.resolve(PUBLIC_DIR,file);
  if(!target.startsWith(PUBLIC_DIR))return send(res,403,{error:"Forbidden"});
  if(!fs.existsSync(target)||fs.statSync(target).isDirectory())return send(res,404,{error:"Not found"});
  const ext=path.extname(target), types={".html":"text/html; charset=utf-8",".js":"text/javascript; charset=utf-8",".css":"text/css; charset=utf-8"};
  res.writeHead(200,{"Content-Type":types[ext]||"application/octet-stream"});fs.createReadStream(target).pipe(res);
}
const server=http.createServer(async(req,res)=>{
  try{
    if(req.method==="OPTIONS")return send(res,204,"");
    const u=new URL(req.url,`http://${req.headers.host}`);
    if(u.pathname==="/health")return send(res,200,{ok:true,service:"Haroon AI Bridge V1",queue:queue.length,bridgeConfigured:!!BRIDGE_TOKEN});
    if(u.pathname==="/api/poll"){
      if(!bridgeAuth(req))return send(res,401,{error:"Invalid Bridge Connect password"});
      return send(res,200,{ok:true,command:queue.shift()||null});
    }
    if(u.pathname==="/api/result"&&req.method==="POST"){
      if(!bridgeAuth(req))return send(res,401,{error:"Invalid Bridge Connect password"});
      const b=await readBody(req);results.set(b.id,{...b,receivedAt:Date.now()});return send(res,200,{ok:true});
    }
    if(u.pathname==="/api/result"&&req.method==="GET"){
      return send(res,200,{ok:true,result:results.get(u.searchParams.get("id"))||null});
    }
    if(u.pathname==="/api/chat"&&req.method==="POST"){
      const b=await readBody(req);if(!b.text?.trim())return send(res,400,{error:"Empty message"});
      const id=b.chatId||crypto.randomUUID(), h=chats.get(id)||[], p=await plan(b.text.trim(),h);
      h.push({role:"user",text:b.text.trim()},{role:"assistant",text:p.reply,operations:p.operations||[]});chats.set(id,h);
      let commandId=null;
      if(p.operations?.length){commandId=crypto.randomUUID();queue.push({id:commandId,chatId:id,createdAt:Date.now(),operations:p.operations});}
      return send(res,200,{ok:true,chatId:id,commandId,reply:p.reply,operations:p.operations||[],queued:!!commandId});
    }
    serve(res,u.pathname);
  }catch(e){send(res,500,{error:e.message||"Server error"});}
});
server.listen(PORT,HOST,()=>console.log(`Haroon AI V1 listening on ${HOST}:${PORT}`));
