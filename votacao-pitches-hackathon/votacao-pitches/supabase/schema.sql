-- =====================================================================
-- Votação de Pitches de Inovação — estrutura Supabase
-- Rode inteiro no SQL Editor do projeto (pode rodar de novo sem quebrar).
-- =====================================================================

-- Pitches avaliados (ids iguais aos do config.js)
create table if not exists public.pitches (
  id     int primary key,
  ordem  int  not null,
  titulo text not null
);

-- Liga/desliga a votação (linha única)
create table if not exists public.votacao_config (
  id            boolean primary key default true check (id),
  aberta        boolean not null default true,
  atualizado_em timestamptz not null default now()
);
insert into public.votacao_config default values on conflict do nothing;

-- Um voto por pessoa (aparelho) por pitch. Votar de novo atualiza a nota.
create table if not exists public.votos (
  voter_id      uuid not null,
  pitch_id      int  not null references public.pitches(id) on delete cascade,
  nota          int  not null check (nota between 0 and 5),
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  primary key (voter_id, pitch_id)
);
create index if not exists votos_pitch_idx on public.votos (pitch_id);

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

-- ---------------------------------------------------------------------
-- Segurança: ninguém lê nem grava "votos" direto pela API.
-- Tudo passa pelas duas funções abaixo.
-- ---------------------------------------------------------------------
alter table public.pitches        enable row level security;
alter table public.votacao_config enable row level security;
alter table public.votos          enable row level security;

drop policy if exists "pitches_leitura" on public.pitches;
create policy "pitches_leitura" on public.pitches
  for select to anon, authenticated using (true);

drop policy if exists "config_leitura" on public.votacao_config;
create policy "config_leitura" on public.votacao_config
  for select to anon, authenticated using (true);
-- (sem policies em "votos" = acesso direto bloqueado)

-- Registra ou altera a nota de um pitch
create or replace function public.registrar_voto(p_voter uuid, p_pitch int, p_nota int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not coalesce((select aberta from votacao_config where id), false) then
    raise exception 'votacao_encerrada';
  end if;
  if p_voter is null or p_nota is null or p_nota not between 0 and 5 then
    raise exception 'voto_invalido';
  end if;
  if not exists (select 1 from pitches where id = p_pitch) then
    raise exception 'pitch_invalido';
  end if;

  insert into votos (voter_id, pitch_id, nota)
  values (p_voter, p_pitch, p_nota)
  on conflict (voter_id, pitch_id)
  do update set nota = excluded.nota, atualizado_em = now();
end;
$$;

-- Dados agregados para o telão (nunca expõe votos individuais)
create or replace function public.painel()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'aberta',        (select aberta from votacao_config where id),
    'participantes', (select count(distinct voter_id) from votos),
    'total_votos',   (select count(*) from votos),
    'itens', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.ordem)
      from (
        select p.id, p.ordem, p.titulo,
               count(v.nota)              as votos,
               round(avg(v.nota), 2)      as media,
               jsonb_build_array(
                 count(*) filter (where v.nota = 0),
                 count(*) filter (where v.nota = 1),
                 count(*) filter (where v.nota = 2),
                 count(*) filter (where v.nota = 3),
                 count(*) filter (where v.nota = 4),
                 count(*) filter (where v.nota = 5)
               )                          as dist
        from pitches p
        left join votos v on v.pitch_id = p.id
        group by p.id, p.ordem, p.titulo
      ) x
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.registrar_voto(uuid, int, int) from public;
revoke all on function public.painel() from public;
grant execute on function public.registrar_voto(uuid, int, int) to anon, authenticated;
grant execute on function public.painel() to anon, authenticated;

-- ---------------------------------------------------------------------
-- Comandos úteis no dia (rodar manualmente no SQL Editor)
-- ---------------------------------------------------------------------
-- Encerrar votação:  update votacao_config set aberta = false, atualizado_em = now();
-- Reabrir:           update votacao_config set aberta = true,  atualizado_em = now();
-- Zerar testes:      truncate votos;
-- Ver resultado:     select jsonb_pretty(painel());
