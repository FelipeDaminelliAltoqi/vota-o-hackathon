-- =====================================================================
-- VOTAÇÃO DOS PITCHES · v3
-- • voto popular liberado/bloqueado por equipe no painel
-- • banca vota pelo link geral (e-mail + código) e tem impedimentos por pitch
-- • nota final fixa: popular = 1 nota + 1 nota por jurado (sem opção 50/50)
--
-- Rode inteiro no SQL Editor, DEPOIS do 03-v2-regras-completas.sql.
-- =====================================================================

-- ---------- pitch 9 fora ----------
delete from public.pitches where id = 9;

-- ---------- status da votação popular por pitch ----------
alter table public.pitches add column if not exists status_popular text not null default 'aguardando';
alter table public.pitches drop constraint if exists pitches_status_chk;
alter table public.pitches add constraint pitches_status_chk check (status_popular in ('aguardando', 'aberta', 'encerrada'));

-- ---------- regra única da nota final ----------
update public.votacao_config set modo_final = 'popular_como_jurado', banca_aberta = true where id;

-- ---------- banca: e-mail único + impedimentos ----------
update public.banca_membros set email = nullif(lower(trim(email)), '');
create unique index if not exists banca_membros_email_uidx on public.banca_membros (email) where email is not null;
create table if not exists public.banca_impedimentos (
  membro_id bigint not null references public.banca_membros(id) on delete cascade,
  pitch_id  int    not null references public.pitches(id) on delete cascade,
  primary key (membro_id, pitch_id)
);
alter table public.banca_impedimentos enable row level security;

create or replace function public.gerar_codigo()
returns text language plpgsql security definer set search_path = public as $$
declare v text; alf text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
begin
  loop
    v := '';
    for k in 1..6 loop v := v || substr(alf, 1 + floor(random() * length(alf))::int, 1); end loop;
    exit when not exists (select 1 from banca_membros where codigo = v);
  end loop;
  return v;
end; $$;

-- jurados (código gerado automaticamente; veja no painel)
insert into public.banca_membros (nome, email, codigo)
select v.nome, v.email, public.gerar_codigo()
from (values
  ('Evandro Vieira', 'evandro.vieira@altoqi.com.br'),
  ('Roberta Feijó',  'roberta.feijo@altoqi.com.br'),
  ('Felipe Roque',   'felipe.roque@altoqi.com.br'),
  ('Raquel Ramos',   'raquel.ramos@altoqi.com.br'),
  ('Marcelo',        'marcelo@altoqi.com.br'),
  ('Banki',          'banki@altoqi.com.br'),
  ('Koerich',        'koerich@altoqi.com.br'),
  ('Miguel Neto',    'miguel.neto@altoqi.com.br'),
  ('Felipe Althoff', 'felipe.althoff@altoqi.com.br'),
  ('Rui',            'rui@altoqi.com.br'),
  ('Pereira',        'pereira@altoqi.com.br')
) v(nome, email)
where not exists (select 1 from public.banca_membros m where m.email = v.email);

-- quem NÃO avalia qual pitch (conflito de interesse)
insert into public.banca_impedimentos (membro_id, pitch_id)
select m.id, v.pitch_id
from (values
  ('evandro.vieira@altoqi.com.br', 1),  -- Solicitação de compras e pagamentos
  ('roberta.feijo@altoqi.com.br',  2),  -- Plataforma de engajamento e desenvolvimento
  ('felipe.roque@altoqi.com.br',   3),  -- Captação de leads para B2B Escritórios
  ('raquel.ramos@altoqi.com.br',   4),  -- Renovação automática
  ('marcelo@altoqi.com.br',        5),  -- Enriquecimento inteligente da base de contatos
  ('banki@altoqi.com.br',          6),  -- Testes com IA em aplicações desktop e web
  ('koerich@altoqi.com.br',        7),  -- Gestão da carteira de clientes governamentais
  ('miguel.neto@altoqi.com.br',    8)   -- Fabricante 360 | Inteligência com IA
) v(email, pitch_id)
join public.banca_membros m on m.email = v.email
on conflict do nothing;

-- jurado de teste da v2 sem e-mail não serve mais (login é por e-mail)
delete from public.banca_membros where email is null;

-- =====================================================================
-- CÁLCULO: nota popular (1) + nota de cada jurado, tudo na mesma média
-- =====================================================================
create or replace function public.resultado_interno()
returns jsonb language sql stable security definer set search_path = public as $$
  with pop as (
    select pitch_id, count(*) n, avg((inovar + conectar + transformar) / 3.0) media,
           avg(inovar) i, avg(conectar) c, avg(transformar) t
    from votos_populares group by pitch_id
  ), ban as (
    select vb.pitch_id, count(*) n,
           avg((vb.inovar + vb.conectar + vb.transformar) / 3.0) media,
           sum((vb.inovar + vb.conectar + vb.transformar) / 3.0) soma,
           avg(vb.inovar) i, avg(vb.conectar) c, avg(vb.transformar) t
    from votos_banca vb join banca_membros m on m.id = vb.membro_id and m.ativo
    group by vb.pitch_id
  )
  select coalesce(jsonb_agg(to_jsonb(r) order by r.ordem), '[]'::jsonb) from (
    select p.id, p.ordem, p.titulo,
      coalesce(pop.n, 0) as pop_votos,   round(pop.media, 2) as pop_media,
      round(pop.i, 2) as pop_inovar, round(pop.c, 2) as pop_conectar, round(pop.t, 2) as pop_transformar,
      coalesce(ban.n, 0) as banca_votos, round(ban.media, 2) as banca_media,
      round(ban.i, 2) as banca_inovar, round(ban.c, 2) as banca_conectar, round(ban.t, 2) as banca_transformar,
      round(case
        when pop.media is null and ban.media is null then null
        when pop.media is null then ban.media
        when ban.media is null then pop.media
        else (pop.media + ban.soma) / (1 + ban.n)
      end, 2) as final
    from pitches p
    left join pop on pop.pitch_id = p.id
    left join ban on ban.pitch_id = p.id
  ) r;
$$;

-- =====================================================================
-- ENTRADA PELO LINK GERAL
-- =====================================================================
-- 1º passo: diz se o e-mail é da banca (pede código) ou público (pede setor)
create or replace function public.identificar(p_email text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_email text := lower(trim(coalesce(p_email, ''))); v_dom text;
begin
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalido'; end if;
  if exists (select 1 from banca_membros where email = v_email and ativo) then
    return jsonb_build_object('tipo', 'banca');
  end if;
  select nullif(trim(dominio_email), '') into v_dom from votacao_config where id;
  if v_dom is not null and v_email not like '%@' || lower(v_dom) then raise exception 'email_dominio'; end if;
  return jsonb_build_object('tipo', 'popular');
end; $$;

create or replace function public.votante_entrar(p_email text, p_setor text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_email text := lower(trim(coalesce(p_email, ''))); v_setor text := trim(coalesce(p_setor, '')); v_dom text;
begin
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalido'; end if;
  if exists (select 1 from banca_membros where email = v_email and ativo) then raise exception 'email_banca'; end if;
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
declare v_email text := lower(trim(coalesce(p_email, ''))); v_status text; v_n int;
begin
  if not exists (select 1 from votantes where email = v_email) then raise exception 'votante_desconhecido'; end if;
  select status_popular into v_status from pitches where id = p_pitch;
  if v_status is null then raise exception 'pitch_invalido'; end if;
  if v_status <> 'aberta' then raise exception 'pitch_fechado'; end if;
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

-- ---------- banca ----------
create or replace function public.banca_json(p_id bigint)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', m.id, 'nome', m.nome, 'email', m.email, 'codigo', m.codigo,
    'aberta', (select banca_aberta from votacao_config where id),
    'impedidos', coalesce((select jsonb_agg(pitch_id) from banca_impedimentos where membro_id = m.id), '[]'::jsonb),
    'votos', coalesce((select jsonb_object_agg(pitch_id::text, jsonb_build_array(inovar, conectar, transformar))
                       from votos_banca where membro_id = m.id), '{}'::jsonb)
  ) from banca_membros m where m.id = p_id;
$$;

-- pelo link pessoal (só código)
create or replace function public.banca_entrar(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  select id into v_id from banca_membros where codigo = upper(trim(coalesce(p_codigo, ''))) and ativo;
  if v_id is null then raise exception 'codigo_invalido'; end if;
  return banca_json(v_id);
end; $$;

-- pelo link geral (e-mail + código)
create or replace function public.banca_entrar_email(p_email text, p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  select id into v_id from banca_membros
  where email = lower(trim(coalesce(p_email, ''))) and codigo = upper(trim(coalesce(p_codigo, ''))) and ativo;
  if v_id is null then raise exception 'codigo_invalido'; end if;
  return banca_json(v_id);
end; $$;

create or replace function public.votar_banca(p_codigo text, p_pitch int, p_inovar int, p_conectar int, p_transformar int)
returns void language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  select id into v_id from banca_membros where codigo = upper(trim(coalesce(p_codigo, ''))) and ativo;
  if v_id is null then raise exception 'codigo_invalido'; end if;
  if not coalesce((select banca_aberta from votacao_config where id), false) then raise exception 'banca_encerrada'; end if;
  if not exists (select 1 from pitches where id = p_pitch) then raise exception 'pitch_invalido'; end if;
  if exists (select 1 from banca_impedimentos where membro_id = v_id and pitch_id = p_pitch) then raise exception 'impedido'; end if;
  if p_inovar is null or p_conectar is null or p_transformar is null
     or p_inovar not between 0 and 5 or p_conectar not between 0 and 5 or p_transformar not between 0 and 5 then
    raise exception 'voto_invalido';
  end if;
  insert into votos_banca (membro_id, pitch_id, inovar, conectar, transformar)
  values (v_id, p_pitch, p_inovar, p_conectar, p_transformar)
  on conflict (membro_id, pitch_id) do update
    set inovar = excluded.inovar, conectar = excluded.conectar, transformar = excluded.transformar, atualizado_em = now();
end; $$;

-- ---------- telão ----------
create or replace function public.painel_publico()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'aberta',    exists (select 1 from pitches where status_popular = 'aberta'),
    'liberado',  c.resultado_liberado,
    'rodada',    c.rodada,
    'votantes',  (select count(distinct email) from votos_populares),
    'votos',     (select count(*) from votos_populares),
    'por_pitch', (select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'ordem', p.ordem, 'titulo', p.titulo, 'status', p.status_popular,
                    'votos', (select count(*) from votos_populares v where v.pitch_id = p.id)) order by p.ordem), '[]'::jsonb) from pitches p),
    'resultado', case when c.resultado_liberado then resultado_interno() else null end
  ) from votacao_config c where c.id;
$$;

-- =====================================================================
-- PAINEL INTERNO
-- =====================================================================
create or replace function public.admin_dados()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  return jsonb_build_object(
    'config',    (select to_jsonb(c) from votacao_config c where c.id),
    'resultado', resultado_interno(),
    'pitches',   coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'ordem', p.ordem, 'titulo', p.titulo, 'status', p.status_popular,
                   'votos', (select count(*) from votos_populares v where v.pitch_id = p.id),
                   'banca', (select count(*) from votos_banca v where v.pitch_id = p.id)) order by p.ordem) from pitches p), '[]'::jsonb),
    'votantes',  coalesce((select jsonb_agg(jsonb_build_object('email', v.email, 'setor', v.setor, 'criado_em', v.criado_em,
                   'votos', (select count(*) from votos_populares x where x.email = v.email)) order by v.criado_em) from votantes v), '[]'::jsonb),
    'votos_populares', coalesce((select jsonb_agg(jsonb_build_object('email', v.email, 'setor', t.setor, 'pitch_id', v.pitch_id, 'pitch', p.titulo,
                   'inovar', v.inovar, 'conectar', v.conectar, 'transformar', v.transformar,
                   'media', round((v.inovar + v.conectar + v.transformar) / 3.0, 2), 'criado_em', v.criado_em) order by v.criado_em desc)
                 from votos_populares v join votantes t on t.email = v.email join pitches p on p.id = v.pitch_id), '[]'::jsonb),
    'membros',   coalesce((select jsonb_agg(jsonb_build_object('id', m.id, 'nome', m.nome, 'email', m.email, 'codigo', m.codigo, 'ativo', m.ativo,
                   'impedidos', coalesce((select jsonb_agg(i.pitch_id) from banca_impedimentos i where i.membro_id = m.id), '[]'::jsonb),
                   'votos', (select count(*) from votos_banca x where x.membro_id = m.id)) order by m.id) from banca_membros m), '[]'::jsonb),
    'votos_banca', coalesce((select jsonb_agg(jsonb_build_object('membro_id', m.id, 'jurado', m.nome, 'email', m.email, 'ativo', m.ativo, 'pitch_id', v.pitch_id, 'pitch', p.titulo,
                   'inovar', v.inovar, 'conectar', v.conectar, 'transformar', v.transformar,
                   'media', round((v.inovar + v.conectar + v.transformar) / 3.0, 2), 'atualizado_em', v.atualizado_em) order by m.nome, p.ordem)
                 from votos_banca v join banca_membros m on m.id = v.membro_id join pitches p on p.id = v.pitch_id), '[]'::jsonb)
  );
end; $$;

create or replace function public.admin_pitch_status(p_pitch int, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  if p_status not in ('aguardando', 'aberta', 'encerrada') then raise exception 'status_invalido'; end if;
  update pitches set status_popular = p_status where id = p_pitch;
end; $$;

drop function if exists public.admin_definir(boolean, boolean, boolean, text, text);
create or replace function public.admin_definir(p_liberado boolean default null, p_dominio text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  update votacao_config set
    resultado_liberado = coalesce(p_liberado, resultado_liberado),
    dominio_email      = case when p_dominio is null then dominio_email else nullif(lower(trim(p_dominio)), '') end,
    atualizado_em      = now()
  where id;
end; $$;

drop function if exists public.admin_add_membro(text, text);
create or replace function public.admin_add_membro(p_nome text, p_email text, p_impedido int default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_email text := lower(trim(coalesce(p_email, ''))); v_id bigint; v_cod text;
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  if length(trim(coalesce(p_nome, ''))) < 2 then raise exception 'nome_invalido'; end if;
  if v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'email_invalido'; end if;
  if exists (select 1 from banca_membros where email = v_email) then raise exception 'email_ja_cadastrado'; end if;
  v_cod := gerar_codigo();
  insert into banca_membros (nome, email, codigo) values (trim(p_nome), v_email, v_cod) returning id into v_id;
  if p_impedido is not null then insert into banca_impedimentos values (v_id, p_impedido) on conflict do nothing; end if;
  return jsonb_build_object('id', v_id, 'codigo', v_cod);
end; $$;

-- define o (único) pitch que o jurado não avalia; null = avalia todos
create or replace function public.admin_impedimento(p_membro bigint, p_pitch int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  delete from banca_impedimentos where membro_id = p_membro;
  if p_pitch is not null then
    insert into banca_impedimentos values (p_membro, p_pitch);
    delete from votos_banca where membro_id = p_membro and pitch_id = p_pitch;
  end if;
end; $$;

create or replace function public.admin_resetar(p_confirmacao text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not eh_admin() then raise exception 'nao_autorizado'; end if;
  if p_confirmacao <> 'ZERAR' then raise exception 'confirmacao_invalida'; end if;
  delete from votos_populares where true;
  delete from votantes where true;
  delete from votos_banca where true;
  update pitches set status_popular = 'aguardando' where true;
  update votacao_config set rodada = rodada + 1, aberta = true, banca_aberta = true,
    resultado_liberado = false, atualizado_em = now() where id;
end; $$;

-- ---------- permissões ----------
revoke all on function public.gerar_codigo() from public, anon, authenticated;
revoke all on function public.banca_json(bigint) from public, anon, authenticated;
revoke all on function public.resultado_interno() from public, anon, authenticated;
revoke all on function public.identificar(text) from public;
revoke all on function public.banca_entrar_email(text, text) from public;
revoke all on function public.admin_pitch_status(int, text) from public;
revoke all on function public.admin_definir(boolean, text) from public;
revoke all on function public.admin_add_membro(text, text, int) from public;
revoke all on function public.admin_impedimento(bigint, int) from public;

grant execute on function public.identificar(text)                     to anon, authenticated;
grant execute on function public.banca_entrar_email(text, text)        to anon, authenticated;
grant execute on function public.admin_pitch_status(int, text)         to authenticated;
grant execute on function public.admin_definir(boolean, text)          to authenticated;
grant execute on function public.admin_add_membro(text, text, int)     to authenticated;
grant execute on function public.admin_impedimento(bigint, int)        to authenticated;

-- nova rodada: limpa a tela de quem testou antes
update public.votacao_config set rodada = rodada + 1 where id;

-- Conferir códigos da banca:  select nome, email, codigo from banca_membros order by id;
