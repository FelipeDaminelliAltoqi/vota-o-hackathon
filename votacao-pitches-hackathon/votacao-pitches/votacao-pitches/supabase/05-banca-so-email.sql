-- =====================================================================
-- v3.1 · Banca entra só com o e-mail (sem código). Rode DEPOIS do 04.
-- =====================================================================
drop function if exists public.banca_entrar_email(text, text);

create or replace function public.banca_entrar_email(p_email text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  select id into v_id from banca_membros where email = lower(trim(coalesce(p_email, ''))) and ativo;
  if v_id is null then raise exception 'email_invalido'; end if;
  return banca_json(v_id);
end; $$;

revoke all on function public.banca_entrar_email(text) from public;
grant execute on function public.banca_entrar_email(text) to anon, authenticated;
