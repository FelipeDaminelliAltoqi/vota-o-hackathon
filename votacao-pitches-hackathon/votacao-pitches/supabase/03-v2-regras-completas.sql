-- =====================================================================
-- VOTAÇÃO DOS PITCHES · HACKATHON ALTOQI — v2
-- Popular (e-mail + setor, 1 voto por pitch, 3 critérios) + Banca + Painel interno
--
-- Rode inteiro no SQL Editor. ATENÇÃO: apaga as tabelas de teste da v1 ("votos").
-- Depois, rode o bloco "ADMINS" no final com o seu e-mail.
-- =====================================================================

-- ---------- limpeza da v1 ----------
drop function if exists public.registrar_voto(uuid, int, int);
drop function if exists public.painel();
drop function if exists public.resetar_votacao();
drop table if exists public.votos;

-- ---------- pitches (equipes) ----------
create table if not exists public.pitches (
  id     int primary key,
  ordem  int  not null,
  titulo text not null
);
insert into public.pitches (id, ordem, titulo) values
  (1, 1, 'Solicitação de compras e pagamentos'),
  (2, 2, 'Plataforma de engajamento e desenvolvimento'),
  (3, 3, 'Captação de leads para B2B Escritórios'),
  (4, 4, 'Renovação automática'),
  (5, 5, 'Enriquecimento inteligente da base de contatos'),
  (6, 6, 'Testes com IA em aplicações desktop e web'),
  (7, 7, 'Gestão da carteira de clientes governamentais'),
  (8, 8, 'Fabricante 360 | Inteligência com IA'),
  (9, 9, 'Ferramenta Delivery para as nossas soluções')
on conflict (id) do update set ordem = excluded.ordem, titulo = excluded.titulo;

-- ---------- configuração (linha única) ----------
create table if not exists public.votacao_config (
  id            boolean primary key default true check (id),
  aberta        boolean not null default true,
  atualizado_em timestamptz not null default now()
);
insert into public.votacao_config default values on conflict do nothing;
alter table public.votacao_config add column if not exists rodada             int     not null default 1;
alter table public.votacao_config add column if not exists banca_aberta       boolean not null default true;
alter table public.votacao_config add column if not exists resultado_liberado boolean not null default false;
alter table public.votacao_config add column if not exists modo_final         text    not null default 'popular_como_jurado';
alter table public.votacao_config add column if not exists dominio_email      text;   -- ex.: 'altoqi.com.br' (vazio = qualquer e-mail)
alter table public.votacao_config drop constraint if exists votacao_config_modo_chk;
alter table public.votacao_config add constraint votacao_config_modo_chk check (modo_final in ('popular_como_jurado', 'metade'));

-- ---------- votação popular ----------
create table if not exists public.votantes (
  email     text primary key check (email = lower(email)),
  setor     text not null,
  criado_em timestamptz not null default now()
);
create table if not exists public.votos_populares (
  email       text not null references public.votantes(email) on delete cascade,
  pitch_id    int  not null references public.pitches(id) on delete cascade,
  inovar      int  not null check (inovar      between 0 and 5),
  conectar    int  not null check (conectar    between 0 and 5),
  transformar int  not null check (transformar between 0 and 5),
  criado_em   timestamptz not null default now(),
  primary key (email, pitch_id)
);
create index if not exists votos_populares_pitch_idx on public.votos_populares (pitch_id);

-- ---------- banca ----------
create table if not exists public.banca_membros (
  id        bigint generated always as identity primary key,
  nome      text not null,
  email     text,
  codigo    text not null unique,
  ativo     boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists public.votos_banca (
  membro_id     bigint not null references public.banca_membros(id) on delete cascade,
  pitch_id      int    not null references public.pitches(id) on delete cascade,
  inovar        int    not null check (inovar      between 0 and 5),
  conectar      int    not null check (conectar    between 0 and 5),
  transformar   int    not null check (transformar between 0 and 5),
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  primary key (membro_id, pitch_id)
);

-- ---------- admins do painel interno ----------
create table if not exists public.admins (email text primary key check (email = lower(email)));

-- ---------- segurança: nada é lido direto, tudo via funções ----------
alter table public.pitches         enable row level security;
alter table public.votacao_config  enable row level security;
alter table public.votantes        enable row level security;
alter table public.votos_populares enable row level security;
alter table public.banca_membros   enable row level security;
alter table public.votos_banca     enable row level security;
alter table public.admins          enable row level security;

drop policy if exists "pitches_leitura" on public.pitches;
create policy "pitches_leitura" on public.pitches for select to anon, authenticated using (true);
drop policy if exists "config_leitura" on public.votacao_config;
create policy "config_leitura" on public.votacao_config for select to anon, authenticated using (true);

-- =====================================================================
-- CÁLCULO DO RESULTADO (interno)
--   nota do voto   = média(inovar, conectar, transformar)
--   nota popular   = média das notas dos votos populares do pitch
--   nota da banca  = nota de cada jurado (média dos 3 critérios)
--   final (popular_como_jurado) = média entre a nota popular e as notas de cada jurado
--   final (metade)              = (nota popular + média da banca) / 2
-- =====================================================================
create or replace function public.resultado_interno()
returns jsonb language sql stable security definer set search_path = public as $$
  with pop as (
    select pitch_id, count(*) n,
           avg((inovar + conectar + transformar) / 3.0) media,
           avg(inovar) i, avg(conectar) c, avg(transformar) t
    from votos_populares group by pitch_id
  ), ban as (
    select vb.pitch_id, count(*) n,
           avg((vb.inovar + vb.conectar + vb.transformar) / 3.0) media,
           sum((vb.inovar + vb.conectar + vb.transformar) / 3.0) soma,
           avg(vb.inovar) i, avg(vb.conectar) c, avg(vb.transformar) t
    from votos_banca vb join banca_membros m on m.id = vb.membro_id and m.ativo
    group by vb.pitch_id
  ), cfg as (select modo_final from votacao_config where id)
  select coalesce(jsonb_agg(to_jsonb(r) order by r.ordem), '[]'::jsonb) from (
    select p.id, p.ordem, p.titulo,
      coalesce(pop.n, 0)  as pop_votos,   round(pop.media, 2) as pop_media,
      round(pop.i, 2) as pop_inovar, round(pop.c, 2) as pop_conectar, round(pop.t, 2) as pop_transformar,
      coalesce(ban.n, 0)  as banca_votos, round(ban.media, 2) as banca_media,
      round(ban.i, 2) as banca_inovar, round(ban.c, 2) as banca_conectar, round(ban.t, 2) as banca_transformar,
      round(case
        when pop.media is null and ban.media is null then null
        when pop.media is null then ban.media
        when ban.media is null then pop.media
        when (select modo_final from cfg) = 'metade' then (pop.media + ban.media) / 2
        else (pop.media + ban.soma) / (1 + ban.n)
      end, 2) as final
    from pitches p
    left join pop on pop.pitch_id = p.id
    left join ban on ban.pitch_id = p.id
  ) r;
$$;

-- =====================================================================
-- VOTAÇÃO POPULAR (site público)
-- =====================================================================
create or replace function public.votante_entrar(p_email text, p_setor text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_email text := lower(trim(coalesce(p_email, ''))); v_setor text := trim(coalesce(p_setor, '')); v_dom text;
begin
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalido'; end if;
  select nullif(trim(dominio_email), '') into v_dom from votacao_config where id;
  if v_dom is not null and v_email not like '%@' || lower(v_dom) then raise exception 'email_dominio'; end if;
  if length(v_setor) < 2 then raise exception 'setor_invalido'; end if;
  insert into votantes (email, setor) values (v_email, left(v_setor, 80)) on conflict (email) do nothing;
  return jsonb_build_object(
    'email', v_email,
    'setor', (select setor from votantes where email = v_email),
    'votados', coalesce((select jsonb_agg(pitch_id) from votos_populares where email = v_email), '[]'::jsonb)
  );
end; $$;

create or replace function public.votar_popular(p_email text, p_pitch int, p_inovar int, p_conectar int, p_transformar int)
returns void language plpgsql security definer set search_path = public as $$
declare v_email text := lower(trim(coalesce(p_email, ''))); v_n int;
begin
  if not coalesce((select aberta from votacao_config where id), false) then raise exception 'votacao_encerrada'; end if;
  if not exists (select 1 from votantes where email = v_email) then raise exception 'votante_desconhecido'; end if;
  if not exists (select 1 from pitches where id = p_pitch) then raise exception 'pitch_invalido'; end if;
  if p_inovar is null or p_conectar is null or p_transformar is null
     or p_inovar not between 0 and 5 or p_conectar not between 0 and 5 or p_transformar not between 0 and 5 then
    raise exception 'voto_invalido';
  end if;
  insert into votos_populares (email, pitch_id, inovar, conectar, transformar)
  values (v_email, p_pitch, p_inovar, p_conectar, p_transformar)
  on conflict (email, pitch_id) do nothing;
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'ja_votou'; end if;
end; $$;

-- =====================================================================
-- BANCA (site da banca, acesso por código individual)
-- =====================================================================
create or replace function public.banca_entrar(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare m banca_membros;
begin
  select * into m from banca_membros where codigo = upper(trim(coalesce(p_codigo, ''))) and ativo;
  if not found then raise exception 'codigo_invalido'; end if;
  return jsonb_build_object(
    'id', m.id, 'nome', m.nome,
    'aberta', (select banca_aberta from votacao_config where id),
    'votos', coalesce((select jsonb_object_agg(pitch_id::text, jsonb_build_array(inovar, conectar, transformar))
                       from votos_banca where membro_id = m.id), '{}'::jsonb)
  );
end; $$;

create or replace function public.votar_banca(p_codigo text, p_pitch int, p_inovar int, p_conectar int, p_transformar int)
returns void language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  select id into v_id from banca_membros where codigo = upper(trim(coalesce(p_codigo, ''))) and ativo;
  if v_id is null then raise exception 'codigo_invalido'; end if;
  if not coalesce((select banca_aberta from votacao_config where id), false) then raise exception 'banca_encerrada'; end if;
  if not exists (select 1 from pitches where id = p_pitch) then raise exception 'pitch_invalido'; end if;
  if p_inovar is null or p_conectar is null or p_transformar is null
     or p_inovar not between 0 and 5 or p_conectar not between 0 and 5 or p_transformar not between 0 and 5 then
    raise exception 'voto_invalido';
  end if;
  insert into votos_banca (membro_id, pitch_id, inovar, conectar, transformar)
  values (v_id, p_pitch, p_inovar, p_conectar, p_transformar)
  on conflict (membro_id, pitch_id) do update
    set inovar = excluded.inovar, conectar = excluded.conectar, transformar = excluded.transformar, atualizado_em = now();
end; $$;

-- =====================================================================
-- TELÃO PÚBLICO: participação sempre; notas só depois de liberar
-- =====================================================================
create or replace function public.painel_publico()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'aberta',    c.aberta,
    'liberado',  c.resultado_liberado,
    'rodada',    c.rodada,
    'votantes',  (select count(distinct email) from votos_populares),
    'votos',     (select count(*) from votos_populares),
    'por_pitch', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'ordem', p.ordem, 'titulo', p.titulo,
                    'votos', (select count(*) from votos_populares v where v.pitch_id = p.id)) order by p.ordem), '[]'::jsonb) from pitches p),
    'resultado', case when c.resultado_liberado then resultado_interno() else null end
  ) from votacao_config c where c.id;
$$;

-- =====================================================================
-- PAINEL INTERNO (exige login de admin no Supabase Auth)
-- =====================================================================
create or replace function public.eh_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where email = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;

create or replace function public.admin_dados()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  return jsonb_build_object(
    'config',    (select to_jsonb(c) from votacao_config c where c.id),
    'resultado', resultado_interno(),
    'votantes',  coalesce((select jsonb_agg(jsonb_build_object('email', v.email, 'setor', v.setor, 'criado_em', v.criado_em,
                   'votos', (select count(*) from votos_populares x where x.email = v.email)) order by v.criado_em) from votantes v), '[]'::jsonb),
    'votos_populares', coalesce((select jsonb_agg(jsonb_build_object('email', v.email, 'setor', t.setor, 'pitch_id', v.pitch_id, 'pitch', p.titulo,
                   'inovar', v.inovar, 'conectar', v.conectar, 'transformar', v.transformar,
                   'media', round((v.inovar + v.conectar + v.transformar) / 3.0, 2), 'criado_em', v.criado_em) order by v.criado_em desc)
                 from votos_populares v join votantes t on t.email = v.email join pitches p on p.id = v.pitch_id), '[]'::jsonb),
    'membros',   coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'nome', m.nome, 'email', m.email, 'codigo', m.codigo, 'ativo', m.ativo,
                   'votos', (select count(*) from votos_banca x where x.membro_id = m.id)) order by m.id) from banca_membros m), '[]'::jsonb),
    'votos_banca', coalesce((select jsonb_agg(jsonb_build_object('membro_id', m.id, 'jurado', m.nome, 'ativo', m.ativo, 'pitch_id', v.pitch_id, 'pitch', p.titulo,
                   'inovar', v.inovar, 'conectar', v.conectar, 'transformar', v.transformar,
                   'media', round((v.inovar + v.conectar + v.transformar) / 3.0, 2), 'atualizado_em', v.atualizado_em) order by m.nome, p.ordem)
                 from votos_banca v join banca_membros m on m.id = v.membro_id join pitches p on p.id = v.pitch_id), '[]'::jsonb)
  );
end; $$;

create or replace function public.admin_definir(p_aberta boolean default null, p_banca_aberta boolean default null,
  p_liberado boolean default null, p_modo text default null, p_dominio text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  update votacao_config set
    aberta             = coalesce(p_aberta, aberta),
    banca_aberta       = coalesce(p_banca_aberta, banca_aberta),
    resultado_liberado = coalesce(p_liberado, resultado_liberado),
    modo_final         = coalesce(p_modo, modo_final),
    dominio_email      = case when p_dominio is null then dominio_email else nullif(lower(trim(p_dominio)), '') end,
    atualizado_em      = now()
  where id;
end; $$;

create or replace function public.admin_add_membro(p_nome text, p_email text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_cod text; v_alf text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; v_id bigint;
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  if length(trim(coalesce(p_nome, ''))) < 2 then raise exception 'nome_invalido'; end if;
  loop
    v_cod := '';
    for k in 1..6 loop v_cod := v_cod || substr(v_alf, 1 + floor(random() * length(v_alf))::int, 1); end loop;
    exit when not exists (select 1 from banca_membros where codigo = v_cod);
  end loop;
  insert into banca_membros (nome, email, codigo) values (trim(p_nome), nullif(lower(trim(p_email)), ''), v_cod) returning id into v_id;
  return jsonb_build_object('id', v_id, 'codigo', v_cod);
end; $$;

create or replace function public.admin_membro_ativo(p_id bigint, p_ativo boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  update banca_membros set ativo = p_ativo where id = p_id;
end; $$;

create or replace function public.admin_excluir_voto(p_email text, p_pitch int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  delete from votos_populares where email = lower(trim(p_email)) and pitch_id = p_pitch;
end; $$;

create or replace function public.admin_resetar(p_confirmacao text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  if p_confirmacao <> 'ZERAR' then raise exception 'confirmacao_invalida'; end if;
  delete from votos_populares where true;
  delete from votantes where true;
  delete from votos_banca where true;
  update votacao_config set rodada = rodada + 1, aberta = true, banca_aberta = true,
    resultado_liberado = false, atualizado_em = now() where id;
end; $$;

-- ---------- permissões ----------
revoke all on function public.resultado_interno() from public, anon, authenticated;
revoke all on function public.votante_entrar(text, text) from public;
revoke all on function public.votar_popular(text, int, int, int, int) from public;
revoke all on function public.banca_entrar(text) from public;
revoke all on function public.votar_banca(text, int, int, int, int) from public;
revoke all on function public.painel_publico() from public;
revoke all on function public.eh_admin() from public;
revoke all on function public.admin_dados() from public;
revoke all on function public.admin_definir(boolean, boolean, boolean, text, text) from public;
revoke all on function public.admin_add_membro(text, text) from public;
revoke all on function public.admin_membro_ativo(bigint, boolean) from public;
revoke all on function public.admin_excluir_voto(text, int) from public;
revoke all on function public.admin_resetar(text) from public;

grant execute on function public.votante_entrar(text, text)              to anon, authenticated;
grant execute on function public.votar_popular(text, int, int, int, int)  to anon, authenticated;
grant execute on function public.banca_entrar(text)                       to anon, authenticated;
grant execute on function public.votar_banca(text, int, int, int, int)    to anon, authenticated;
grant execute on function public.painel_publico()                         to anon, authenticated;
grant execute on function public.eh_admin()                               to authenticated;
grant execute on function public.admin_dados()                            to authenticated;
grant execute on function public.admin_definir(boolean, boolean, boolean, text, text) to authenticated;
grant execute on function public.admin_add_membro(text, text)             to authenticated;
grant execute on function public.admin_membro_ativo(bigint, boolean)      to authenticated;
grant execute on function public.admin_excluir_voto(text, int)            to authenticated;
grant execute on function public.admin_resetar(text)                      to authenticated;

-- nova rodada: limpa a tela dos celulares que testaram a v1
update public.votacao_config set rodada = rodada + 1, resultado_liberado = false where id;

-- =====================================================================
-- ADMINS — troque pelo(s) e-mail(s) que vão acessar o painel interno.
-- O mesmo e-mail precisa existir em Authentication > Users (com senha).
-- =====================================================================
-- insert into public.admins (email) values ('seu.email@altoqi.com.br') on conflict do nothing;
