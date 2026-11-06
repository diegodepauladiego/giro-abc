-- =====================================================================
--  GIRO ABC — Lista de pedais
--  Cole TUDO isto no Supabase: SQL Editor > New query > Run
--  Antes de rodar, troque a senha na última seção (TROQUE-ESSA-SENHA).
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- Tabelas ----------
create table if not exists public.pedais (
  id             uuid primary key default gen_random_uuid(),
  titulo         text not null,
  data           date not null,
  hora_saida     time not null,
  local_saida    text not null,
  local_maps_url text,
  distancia_km   numeric(6,1),
  elevacao_m     integer,
  strava_url     text,
  aviso          text,
  observacoes    text,
  limite         integer check (limite is null or limite > 0),
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now()
);

create table if not exists public.inscricoes (
  id         uuid primary key default gen_random_uuid(),
  pedal_id   uuid not null references public.pedais(id) on delete cascade,
  nome       text not null,
  token      uuid not null default gen_random_uuid(),   -- "chave" para a pessoa sair da lista
  criado_em  timestamptz not null default now()
);
create unique index if not exists inscricoes_nome_unico
  on public.inscricoes (pedal_id, lower(nome));

create table if not exists public.config (
  chave text primary key,
  valor text not null
);

-- ---------- Segurança (RLS) ----------
-- pedais: qualquer um pode LER; ninguém grava direto (só pelas funções abaixo)
-- inscricoes / config: ninguém acessa direto (só pelas funções abaixo)
alter table public.pedais     enable row level security;
alter table public.inscricoes enable row level security;
alter table public.config     enable row level security;

drop policy if exists "pedais leitura publica" on public.pedais;
create policy "pedais leitura publica" on public.pedais
  for select to anon, authenticated using (true);

grant select on public.pedais to anon, authenticated;
revoke insert, update, delete on public.pedais from anon, authenticated;
revoke all on public.inscricoes from anon, authenticated;
revoke all on public.config     from anon, authenticated;

-- ---------- Funções internas ----------
create or replace function public._limpa_nome(p text)
returns text language sql immutable as $$
  select left(
    btrim(
      regexp_replace(
        regexp_replace(coalesce(p, ''), '[​-‍⁠﻿]', '', 'g'),
        '\s+', ' ', 'g')
    ), 40)
$$;

create or replace function public._admin_ok(p_senha text)
returns boolean language sql stable security definer
set search_path = public, extensions as $$
  select exists (
    select 1 from public.config
    where chave = 'admin_hash'
      and valor = extensions.crypt(coalesce(p_senha, ''), valor)
  )
$$;

create or replace function public._exige_admin(p_senha text)
returns void language plpgsql security definer
set search_path = public, extensions as $$
begin
  if not public._admin_ok(p_senha) then
    perform pg_sleep(1);                      -- atrasa tentativas de adivinhar a senha
    raise exception 'SENHA_INVALIDA';
  end if;
end $$;

-- ---------- Funções públicas (ciclistas) ----------
-- Lista de nomes de um pedal (sem expor o token)
create or replace function public.lista(p_pedal uuid)
returns table (id uuid, nome text, criado_em timestamptz)
language sql stable security definer set search_path = public as $$
  select i.id, i.nome, i.criado_em
  from public.inscricoes i
  where i.pedal_id = p_pedal
  order by i.criado_em, i.id
$$;

-- Entrar na lista
create or replace function public.entrar(p_pedal uuid, p_nome text)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_nome  text := public._limpa_nome(p_nome);
  v_p     public.pedais;
  v_qtd   int;
  v_id    uuid;
  v_token uuid;
begin
  if char_length(v_nome) < 2 then raise exception 'NOME_INVALIDO'; end if;

  select * into v_p from public.pedais where pedais.id = p_pedal for update;  -- trava p/ não estourar vagas
  if not found or not v_p.ativo then raise exception 'PEDAL_FECHADO'; end if;

  if exists (select 1 from public.inscricoes i
             where i.pedal_id = p_pedal and lower(i.nome) = lower(v_nome)) then
    raise exception 'NOME_REPETIDO';
  end if;

  if v_p.limite is not null then
    select count(*) into v_qtd from public.inscricoes i where i.pedal_id = p_pedal;
    if v_qtd >= v_p.limite then raise exception 'LOTADO'; end if;
  end if;

  insert into public.inscricoes (pedal_id, nome) values (p_pedal, v_nome)
  returning inscricoes.id, inscricoes.token into v_id, v_token;

  return json_build_object('id', v_id, 'token', v_token, 'nome', v_nome);
end $$;

-- Sair da lista (só quem tem o token, gravado no celular de quem se inscreveu)
create or replace function public.sair(p_id uuid, p_token uuid)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  delete from public.inscricoes where id = p_id and token = p_token;
  return found;
end $$;

-- ---------- Funções do organizador (exigem senha) ----------
create or replace function public.admin_login(p_senha text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  perform public._exige_admin(p_senha);
  return true;
end $$;

create or replace function public.admin_salvar_pedal(p_senha text, p jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  perform public._exige_admin(p_senha);

  if nullif(p->>'id', '') is null then
    insert into public.pedais (titulo, data, hora_saida, local_saida, local_maps_url,
      distancia_km, elevacao_m, strava_url, aviso, observacoes, limite, ativo)
    values (
      btrim(p->>'titulo'), (p->>'data')::date, (p->>'hora_saida')::time, btrim(p->>'local_saida'),
      nullif(btrim(p->>'local_maps_url'), ''),
      nullif(p->>'distancia_km', '')::numeric, nullif(p->>'elevacao_m', '')::int,
      nullif(btrim(p->>'strava_url'), ''), nullif(btrim(p->>'aviso'), ''),
      nullif(btrim(p->>'observacoes'), ''), nullif(p->>'limite', '')::int,
      coalesce((p->>'ativo')::boolean, true))
    returning id into v_id;
  else
    update public.pedais set
      titulo         = btrim(p->>'titulo'),
      data           = (p->>'data')::date,
      hora_saida     = (p->>'hora_saida')::time,
      local_saida    = btrim(p->>'local_saida'),
      local_maps_url = nullif(btrim(p->>'local_maps_url'), ''),
      distancia_km   = nullif(p->>'distancia_km', '')::numeric,
      elevacao_m     = nullif(p->>'elevacao_m', '')::int,
      strava_url     = nullif(btrim(p->>'strava_url'), ''),
      aviso          = nullif(btrim(p->>'aviso'), ''),
      observacoes    = nullif(btrim(p->>'observacoes'), ''),
      limite         = nullif(p->>'limite', '')::int,
      ativo          = coalesce((p->>'ativo')::boolean, ativo)
    where id = (p->>'id')::uuid
    returning id into v_id;
  end if;
  return v_id;
end $$;

create or replace function public.admin_excluir_pedal(p_senha text, p_pedal uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._exige_admin(p_senha);
  delete from public.pedais where id = p_pedal;
end $$;

create or replace function public.admin_remover(p_senha text, p_inscricao uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform public._exige_admin(p_senha);
  delete from public.inscricoes where id = p_inscricao;
end $$;

-- O organizador pode colocar alguém na lista mesmo com inscrições encerradas/lotado
create or replace function public.admin_adicionar(p_senha text, p_pedal uuid, p_nome text)
returns void language plpgsql security definer set search_path = public as $$
declare v_nome text := public._limpa_nome(p_nome);
begin
  perform public._exige_admin(p_senha);
  if char_length(v_nome) < 2 then raise exception 'NOME_INVALIDO'; end if;
  insert into public.inscricoes (pedal_id, nome) values (p_pedal, v_nome)
  on conflict (pedal_id, lower(nome)) do nothing;
end $$;

-- ---------- Permissões das funções ----------
revoke all on function public._admin_ok(text)    from public, anon, authenticated;
revoke all on function public._exige_admin(text) from public, anon, authenticated;

grant execute on function public.lista(uuid)                         to anon, authenticated;
grant execute on function public.entrar(uuid, text)                  to anon, authenticated;
grant execute on function public.sair(uuid, uuid)                    to anon, authenticated;
grant execute on function public.admin_login(text)                   to anon, authenticated;
grant execute on function public.admin_salvar_pedal(text, jsonb)     to anon, authenticated;
grant execute on function public.admin_excluir_pedal(text, uuid)     to anon, authenticated;
grant execute on function public.admin_remover(text, uuid)           to anon, authenticated;
grant execute on function public.admin_adicionar(text, uuid, text)   to anon, authenticated;

-- ---------- SENHA DO ORGANIZADOR ----------
-- Troque TROQUE-ESSA-SENHA pela sua senha. Para mudar depois, rode só este bloco de novo.
insert into public.config (chave, valor)
values ('admin_hash', extensions.crypt('TROQUE-ESSA-SENHA', extensions.gen_salt('bf')))
on conflict (chave) do update set valor = excluded.valor;

-- ---------- (Opcional) Primeiro pedal de exemplo ----------
-- insert into public.pedais (titulo, data, hora_saida, local_saida, distancia_km, elevacao_m, aviso)
-- values ('Paranapiacaba x Quarta Divisão', '2026-11-08', '07:00',
--         'Azul de Fome - Avenida Portugal', 75, 1000, 'Não indicado para iniciantes!');
