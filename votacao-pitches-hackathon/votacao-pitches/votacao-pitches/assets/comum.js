/* Núcleo compartilhado: API Supabase, login do painel, modo demonstração e componente de avaliação */
(function(){
  const C = window.VOTACAO_CONFIG;
  const qs = new URLSearchParams(location.search);
  const DEMO = qs.has("demo") || !C.SUPABASE_URL || C.SUPABASE_URL.includes("SEU-PROJETO");
  const CRIT = C.CRITERIOS;
  const dois = (n) => String(n).padStart(2, "0");
  const fmt = (n, d = 2) => (n == null || n === "" || isNaN(n)) ? "–" : Number(n).toLocaleString("pt-BR", { minimumFractionDigits:d, maximumFractionDigits:d });
  const media3 = (a) => (a[0] + a[1] + a[2]) / 3;
  const erro = (codigo, detalhe) => { const e = new Error(codigo); e.codigo = codigo; e.detalhe = detalhe; return e; };
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]));

  const MENSAGENS = {
    rede: "Sem conexão. Confira a internet e tente de novo.",
    falha: "Algo deu errado. Tente de novo.",
    email_invalido: "Confira o e-mail digitado.",
    email_dominio: "Use o seu e-mail corporativo.",
    setor_invalido: "Informe o seu setor.",
    votacao_encerrada: "A votação popular foi encerrada.",
    banca_encerrada: "A avaliação da banca foi encerrada.",
    ja_votou: "Você já votou neste pitch.",
    votante_desconhecido: "Identifique-se de novo para votar.",
    codigo_invalido: "Código não encontrado. Confira com a organização.",
    voto_invalido: "Avalie os 3 critérios.",
    nao_autorizado: "Seu usuário não tem acesso a este painel.",
    login_invalido: "E-mail ou senha incorretos.",
    confirmacao_invalida: "Digite ZERAR para confirmar.",
    nome_invalido: "Informe o nome do jurado.",
    email_banca: "Este e-mail é da banca: informe o código de acesso.",
    pitch_fechado: "A votação deste pitch não está liberada agora.",
    impedido: "Você não avalia este pitch.",
    email_ja_cadastrado: "Esse e-mail já está na banca.",
    status_invalido: "Status inválido."
  };
  const mensagem = (e) => MENSAGENS[e && e.codigo] || (e && e.detalhe) || MENSAGENS.falha;

  // ---------------- API real ----------------
  async function api(fn, body = {}, token){
    if (DEMO) return demoApi(fn, body, token);
    const h = { "Content-Type":"application/json", apikey:C.SUPABASE_ANON_KEY };
    if (token) h.Authorization = "Bearer " + token;
    else if (C.SUPABASE_ANON_KEY.startsWith("eyJ")) h.Authorization = "Bearer " + C.SUPABASE_ANON_KEY;
    let r;
    try{ r = await fetch(`${C.SUPABASE_URL}/rest/v1/rpc/${fn}`, { method:"POST", headers:h, body:JSON.stringify(body), cache:"no-store" }); }
    catch(e){ throw erro("rede"); }
    const txt = await r.text(); let d = null;
    try{ d = txt ? JSON.parse(txt) : null; }catch(e){}
    if (!r.ok){
      const msg = (d && (d.message || d.msg || d.error_description)) || "";
      const cod = /^[a-z_]+$/.test(msg) ? msg : (r.status === 401 || r.status === 403 || /JWT/i.test(msg)) ? "nao_autorizado" : "falha";
      throw erro(cod, msg);
    }
    return d;
  }
  async function lerConfig(){
    if (DEMO){ const d = ddb(); return { ...d.cfg }; }
    const h = { apikey:C.SUPABASE_ANON_KEY };
    if (C.SUPABASE_ANON_KEY.startsWith("eyJ")) h.Authorization = "Bearer " + C.SUPABASE_ANON_KEY;
    const r = await fetch(`${C.SUPABASE_URL}/rest/v1/votacao_config?select=aberta,banca_aberta,rodada,resultado_liberado`, { headers:h, cache:"no-store" });
    const d = await r.json(); return Array.isArray(d) ? d[0] : null;
  }

  // status da votação popular por pitch: { [id]: "aguardando" | "aberta" | "encerrada" }
  async function lerStatus(){
    if (DEMO){ return { ...ddb().status }; }
    const h = { apikey:C.SUPABASE_ANON_KEY };
    if (C.SUPABASE_ANON_KEY.startsWith("eyJ")) h.Authorization = "Bearer " + C.SUPABASE_ANON_KEY;
    const r = await fetch(`${C.SUPABASE_URL}/rest/v1/pitches?select=id,status_popular`, { headers:h, cache:"no-store" });
    if (!r.ok) throw erro("falha");
    const d = await r.json(); const o = {}; d.forEach(x => o[x.id] = x.status_popular); return o;
  }

  // ---------------- login do painel (Supabase Auth) ----------------
  async function auth(grant, body){
    if (DEMO) return { access_token:"demo", refresh_token:"demo", expires_at:Date.now()/1000 + 3600, email: body.email || "demo@altoqi.com.br" };
    let r;
    try{ r = await fetch(`${C.SUPABASE_URL}/auth/v1/token?grant_type=${grant}`, { method:"POST", headers:{ "Content-Type":"application/json", apikey:C.SUPABASE_ANON_KEY }, body:JSON.stringify(body) }); }
    catch(e){ throw erro("rede"); }
    const d = await r.json().catch(() => ({}));
    if (!r.ok) throw erro("login_invalido", d.error_description || d.msg);
    return { access_token:d.access_token, refresh_token:d.refresh_token, expires_at:d.expires_at || (Date.now()/1000 + (d.expires_in || 3600)), email:(d.user && d.user.email) || body.email };
  }
  const login = (email, senha) => auth("password", { email, password:senha });
  const renovar = (refresh) => auth("refresh_token", { refresh_token:refresh });

  // ---------------- cálculo (mesma regra do banco, usado no demo) ----------------
  function calcular(pitches, votos, vb, membros){
    const ativos = new Set(membros.filter(m => m.ativo).map(m => m.id));
    return pitches.map((p, i) => {
      const pv = votos.filter(v => v.pitch_id === p.id), bv = vb.filter(v => v.pitch_id === p.id && ativos.has(v.membro_id));
      const avg = (arr, f) => arr.length ? arr.reduce((a, x) => a + f(x), 0) / arr.length : null;
      const r2 = (x) => x == null ? null : Math.round(x * 100) / 100;
      const pm = avg(pv, v => (v.inovar + v.conectar + v.transformar) / 3);
      const bm = avg(bv, v => (v.inovar + v.conectar + v.transformar) / 3);
      const bs = bv.reduce((a, v) => a + (v.inovar + v.conectar + v.transformar) / 3, 0);
      let fin = null;
      if (pm == null && bm == null) fin = null; else if (pm == null) fin = bm; else if (bm == null) fin = pm;
      else fin = (pm + bs) / (1 + bv.length);
      return { id:p.id, ordem:i + 1, titulo:p.titulo,
        pop_votos:pv.length, pop_media:r2(pm), pop_inovar:r2(avg(pv, v => v.inovar)), pop_conectar:r2(avg(pv, v => v.conectar)), pop_transformar:r2(avg(pv, v => v.transformar)),
        banca_votos:bv.length, banca_media:r2(bm), banca_inovar:r2(avg(bv, v => v.inovar)), banca_conectar:r2(avg(bv, v => v.conectar)), banca_transformar:r2(avg(bv, v => v.transformar)),
        final:r2(fin) };
    });
  }
  function ranking(itens){
    return itens.slice().sort((a, b) => (b.final ?? -1) - (a.final ?? -1) || (b.banca_media ?? -1) - (a.banca_media ?? -1) || (b.pop_media ?? -1) - (a.pop_media ?? -1) || a.ordem - b.ordem);
  }

  // ---------------- modo demonstração (banco falso no navegador) ----------------
  const DKEY = "hq-demo-db:v3";
  function ddb(){
    let d = null; try{ d = JSON.parse(localStorage.getItem(DKEY)); }catch(e){}
    if (!d){
      d = { cfg:{ banca_aberta:true, resultado_liberado:false, rodada:1, dominio_email:null },
            status:{}, votantes:{}, votos:[], membros:[], vb:[], seq:1 };
      semear(d); dsave(d);
    }
    return d;
  }
  function dsave(d){ try{ localStorage.setItem(DKEY, JSON.stringify(d)); }catch(e){} }
  function semear(d){
    const setores = ["Marketing", "Produto", "Engenharia", "Comercial", "Suporte", "Financeiro", "Pessoas"];
    let s = 7; const rnd = () => (s = (s * 9301 + 49297) % 233280) / 233280;
    const peso = {}; C.PITCHES.forEach((p, i) => { peso[p.id] = 1.5 + rnd() * 3; d.status[p.id] = i < 3 ? "encerrada" : i === 3 ? "aberta" : "aguardando"; });
    const nota = (b) => Math.max(0, Math.min(5, Math.round(b + (rnd() - .5) * 2.6)));
    for (let k = 1; k <= 38; k++){
      const email = `pessoa${k}@altoqi.com.br`;
      d.votantes[email] = { setor:setores[k % setores.length], criado_em:new Date(Date.now() - k * 60000).toISOString() };
      C.PITCHES.slice(0, 4).forEach(p => { if (rnd() < .85) d.votos.push({ email, pitch_id:p.id, inovar:nota(peso[p.id]), conectar:nota(peso[p.id]), transformar:nota(peso[p.id]), criado_em:new Date(Date.now() - k * 50000).toISOString() }); });
    }
    [["Jurado Demo", "jurado.demo@altoqi.com.br", "DEMO01", 1], ["Ana Banca", "ana.banca@altoqi.com.br", "DEMO02", 2], ["Bruno Banca", "bruno.banca@altoqi.com.br", "DEMO03", null]].forEach(([nome, email, codigo, imp], i) => {
      const id = d.seq++; d.membros.push({ id, nome, email, codigo, ativo:true, impedidos:imp ? [imp] : [] });
      if (i > 0) C.PITCHES.forEach(p => { if (p.id !== imp) d.vb.push({ membro_id:id, pitch_id:p.id, inovar:nota(peso[p.id]), conectar:nota(peso[p.id]), transformar:nota(peso[p.id]), atualizado_em:new Date().toISOString() }); });
    });
  }
  async function demoApi(fn, b){
    await new Promise(r => setTimeout(r, 250 + Math.random() * 250));
    const d = ddb(); const res = (x) => { dsave(d); return x; };
    const resultado = () => calcular(C.PITCHES, d.votos, d.vb, d.membros);
    const okEmail = (e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
    const membroEmail = (e) => d.membros.find(m => m.email === e && m.ativo);
    const membroCod = (c) => d.membros.find(m => m.codigo === String(c || "").trim().toUpperCase() && m.ativo);
    const bancaJson = (m) => { const votos = {}; d.vb.filter(v => v.membro_id === m.id).forEach(v => votos[v.pitch_id] = [v.inovar, v.conectar, v.transformar]);
      return { id:m.id, nome:m.nome, email:m.email, codigo:m.codigo, aberta:d.cfg.banca_aberta, impedidos:m.impedidos.slice(), votos }; };
    const tit = (id) => (C.PITCHES.find(p => p.id === id) || {}).titulo;
    switch (fn){
      case "identificar": {
        const email = String(b.p_email || "").trim().toLowerCase();
        if (!okEmail(email)) throw erro("email_invalido");
        return { tipo: membroEmail(email) ? "banca" : "popular" };
      }
      case "votante_entrar": {
        const email = String(b.p_email || "").trim().toLowerCase();
        if (!okEmail(email)) throw erro("email_invalido");
        if (membroEmail(email)) throw erro("email_banca");
        if (String(b.p_setor || "").trim().length < 2) throw erro("setor_invalido");
        if (!d.votantes[email]) d.votantes[email] = { setor:b.p_setor.trim(), criado_em:new Date().toISOString() };
        return res({ email, setor:d.votantes[email].setor, votados:d.votos.filter(v => v.email === email).map(v => v.pitch_id) });
      }
      case "votar_popular": {
        const email = String(b.p_email).toLowerCase();
        if (!d.votantes[email]) throw erro("votante_desconhecido");
        if (d.status[b.p_pitch] !== "aberta") throw erro("pitch_fechado");
        if (d.votos.some(v => v.email === email && v.pitch_id === b.p_pitch)) throw erro("ja_votou");
        d.votos.push({ email, pitch_id:b.p_pitch, inovar:b.p_inovar, conectar:b.p_conectar, transformar:b.p_transformar, criado_em:new Date().toISOString() });
        return res(null);
      }
      case "banca_entrar": { const m = membroCod(b.p_codigo); if (!m) throw erro("codigo_invalido"); return bancaJson(m); }
      case "banca_entrar_email": {
        const m = membroEmail(String(b.p_email || "").trim().toLowerCase());
        if (!m) throw erro("email_invalido");
        return bancaJson(m);
      }
      case "votar_banca": {
        const m = membroCod(b.p_codigo);
        if (!m) throw erro("codigo_invalido");
        if (!d.cfg.banca_aberta) throw erro("banca_encerrada");
        if (m.impedidos.includes(b.p_pitch)) throw erro("impedido");
        const v = d.vb.find(x => x.membro_id === m.id && x.pitch_id === b.p_pitch);
        const novo = { membro_id:m.id, pitch_id:b.p_pitch, inovar:b.p_inovar, conectar:b.p_conectar, transformar:b.p_transformar, atualizado_em:new Date().toISOString() };
        if (v) Object.assign(v, novo); else d.vb.push(novo);
        return res(null);
      }
      case "painel_publico":
        return { aberta:Object.values(d.status).includes("aberta"), liberado:d.cfg.resultado_liberado, rodada:d.cfg.rodada,
          votantes:new Set(d.votos.map(v => v.email)).size, votos:d.votos.length,
          por_pitch:C.PITCHES.map((p, i) => ({ id:p.id, ordem:i + 1, titulo:p.titulo, status:d.status[p.id], votos:d.votos.filter(v => v.pitch_id === p.id).length })),
          resultado:d.cfg.resultado_liberado ? resultado() : null };
      case "admin_dados":
        return { config:{ ...d.cfg }, resultado:resultado(),
          pitches:C.PITCHES.map((p, i) => ({ id:p.id, ordem:i + 1, titulo:p.titulo, status:d.status[p.id], votos:d.votos.filter(v => v.pitch_id === p.id).length, banca:d.vb.filter(v => v.pitch_id === p.id).length })),
          votantes:Object.entries(d.votantes).map(([email, v]) => ({ email, setor:v.setor, criado_em:v.criado_em, votos:d.votos.filter(x => x.email === email).length })),
          votos_populares:d.votos.map(v => ({ ...v, setor:(d.votantes[v.email] || {}).setor, pitch:tit(v.pitch_id), media:Math.round(media3([v.inovar, v.conectar, v.transformar]) * 100) / 100 })).reverse(),
          membros:d.membros.map(m => ({ ...m, votos:d.vb.filter(v => v.membro_id === m.id).length })),
          votos_banca:d.vb.map(v => { const m = d.membros.find(x => x.id === v.membro_id) || {}; return { ...v, jurado:m.nome, email:m.email, ativo:m.ativo, pitch:tit(v.pitch_id), media:Math.round(media3([v.inovar, v.conectar, v.transformar]) * 100) / 100 }; }) };
      case "admin_pitch_status": d.status[b.p_pitch] = b.p_status; return res(null);
      case "admin_definir":
        if (b.p_liberado != null) d.cfg.resultado_liberado = b.p_liberado;
        if (b.p_dominio != null) d.cfg.dominio_email = b.p_dominio.trim() || null;
        return res(null);
      case "admin_add_membro": {
        const email = String(b.p_email || "").trim().toLowerCase();
        if (String(b.p_nome || "").trim().length < 2) throw erro("nome_invalido");
        if (!okEmail(email)) throw erro("email_invalido");
        if (d.membros.some(m => m.email === email)) throw erro("email_ja_cadastrado");
        const alf = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; let cod = ""; for (let k = 0; k < 6; k++) cod += alf[Math.floor(Math.random() * alf.length)];
        const id = d.seq++; d.membros.push({ id, nome:b.p_nome.trim(), email, codigo:cod, ativo:true, impedidos:b.p_impedido ? [b.p_impedido] : [] });
        return res({ id, codigo:cod });
      }
      case "admin_impedimento": {
        const m = d.membros.find(x => x.id === b.p_membro); if (!m) return null;
        m.impedidos = b.p_pitch ? [b.p_pitch] : [];
        if (b.p_pitch) d.vb = d.vb.filter(v => !(v.membro_id === m.id && v.pitch_id === b.p_pitch));
        return res(null);
      }
      case "admin_membro_ativo": { const m = d.membros.find(x => x.id === b.p_id); if (m) m.ativo = b.p_ativo; return res(null); }
      case "admin_excluir_voto": d.votos = d.votos.filter(v => !(v.email === b.p_email && v.pitch_id === b.p_pitch)); return res(null);
      case "admin_resetar":
        if (b.p_confirmacao !== "ZERAR") throw erro("confirmacao_invalida");
        d.votos = []; d.votantes = {}; d.vb = []; d.cfg.rodada++; d.cfg.banca_aberta = true; d.cfg.resultado_liberado = false;
        C.PITCHES.forEach(p => d.status[p.id] = "aguardando");
        return res(null);
    }
    throw erro("falha", "função demo desconhecida: " + fn);
  }

  // ---------------- componente: 3 critérios com escala 0–5 ----------------
  // cria a avaliação dentro de "alvo"; onChange recebe [inovar, conectar, transformar] (null onde falta)
  function criarAvaliacao(alvo, opcoes = {}){
    const valores = [null, null, null];
    const blocos = CRIT.map((c, ci) => {
      const el = document.createElement("div"); el.className = "crit";
      el.innerHTML = `<div class="crit-cab"><h3>${esc(c.nome)}</h3><span class="crit-nota" aria-hidden="true">–</span></div>
        <p class="crit-desc">${esc(c.descricao)}</p><div class="escala" role="group" aria-label="Nota para ${esc(c.nome)}"></div>`;
      const escala = el.querySelector(".escala");
      for (let n = 0; n <= 5; n++){
        const b = document.createElement("button");
        b.type = "button"; b.dataset.nota = n; b.style.setProperty("--i", n); b.setAttribute("aria-pressed", "false");
        b.setAttribute("aria-label", `${c.nome}: nota ${n}` + (n === 0 ? `, ${C.ROTULO_MIN}` : n === 5 ? `, ${C.ROTULO_MAX}` : ""));
        b.innerHTML = `<span class="barra"></span><span class="rot">${n}</span>`;
        b.addEventListener("click", () => { if (api_.travado) return; valores[ci] = n; pintar(); opcoes.onChange && opcoes.onChange(valores.slice()); });
        escala.appendChild(b);
      }
      alvo.appendChild(el); return el;
    });
    function pintar(){
      blocos.forEach((el, ci) => {
        const v = valores[ci];
        el.classList.toggle("feito", v != null);
        el.querySelector(".crit-nota").textContent = v == null ? "–" : v;
        el.querySelectorAll(".escala button").forEach(b => {
          const n = +b.dataset.nota;
          b.classList.toggle("cheio", v != null && n <= v);
          b.setAttribute("aria-pressed", String(n === v));
          b.disabled = api_.travado;
        });
      });
    }
    const api_ = {
      travado:false,
      valores:() => valores.slice(),
      completo:() => valores.every(v => v != null),
      definir(vals){ for (let i = 0; i < 3; i++) valores[i] = vals && vals[i] != null ? vals[i] : null; pintar(); },
      travar(t){ api_.travado = !!t; pintar(); }
    };
    pintar();
    return api_;
  }

  // ---------------- utilidades de interface ----------------
  function csv(linhas){ return "\ufeff" + linhas.map(l => l.map(c => { const s = c == null ? "" : String(c); return /[;"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; }).join(";")).join("\n"); }
  function baixar(nome, conteudo, tipo = "text/csv;charset=utf-8"){
    const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([conteudo], { type:tipo })); a.download = nome;
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(a.href), 1500);
  }
  const numBR = (n) => n == null ? "" : String(n).replace(".", ",");
  const carimbo = () => new Date().toISOString().slice(0, 16).replace(/[:T]/g, "-");

  window.HQ = { C, DEMO, CRIT, dois, fmt, media3, esc, erro, mensagem, api, lerConfig, lerStatus, login, renovar, calcular, ranking,
    criarAvaliacao, csv, baixar, numBR, carimbo, resetDemo:() => localStorage.removeItem(DKEY) };
})();
