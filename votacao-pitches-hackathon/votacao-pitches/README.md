# Votação dos pitches · Hackathon AltoQi

Site estático (sem build) + Supabase. Identidade: Design System Diamante do Hackathon (Figma).

| Arquivo | O que é |
|---|---|
| `index.html` | Votação mobile (é o link do QR code) |
| `resultados.html` | Telão: ranking ao vivo, QR code, participantes, exportar CSV |
| `config.js` | Supabase, textos e lista dos 9 pitches |
| `supabase/schema.sql` | Tabelas, segurança (RLS) e funções |
| `netlify.toml` | Configuração do deploy |
| `assets/` | Logo, favicon, fontes e gerador de QR (tudo local, sem CDN) |

## 1. Banco (uma vez)
Supabase > projeto `doiaflynbljzfvyftoxg` > SQL Editor > cole o conteúdo de `supabase/schema.sql` > Run.

## 2. GitHub (pelo navegador)
1. github.com/new > crie o repositório (ex.: `votacao-pitches-hackathon`).
2. Na página do repo: "uploading an existing file" > arraste o **conteúdo** desta pasta (incluindo `assets/` e `supabase/`) > Commit.

## 3. Netlify
Add new site > Import an existing project > GitHub > escolha o repo > Deploy (não precisa preencher build).
Cada commit no GitHub publica sozinho.

- Votação: `https://SEU-SITE.netlify.app/`
- Telão: `https://SEU-SITE.netlify.app/resultados`

## Testar sem mexer no banco
Acrescente `?demo` na URL (ex.: `/resultados?demo`). Dados simulados, nada é gravado.

## No dia
- Encerrar votação: `update votacao_config set aberta = false;`
- Reabrir: `update votacao_config set aberta = true;`
- Zerar testes antes do evento: `truncate votos;`
- Abra o projeto Supabase na véspera (plano gratuito pausa após dias sem uso).

## Como funciona
- Cada celular recebe um id anônimo. Uma nota por celular por pitch; tocar de novo altera.
- Cada toque é salvo na hora, com retentativa se a rede oscilar.
- O telão lê a função `painel()` a cada 2 s. Votos individuais não são expostos pela API.
- Aba anônima ou outro navegador contam como outro votante (aceitável para evento interno).
