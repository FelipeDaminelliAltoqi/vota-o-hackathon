# Votação dos pitches · Hackathon AltoQi (v2)

| Página | Endereço | Para quem |
|---|---|---|
| Votação popular | `/` | Público (QR code). Pede e-mail + setor; 1 voto por pitch, sem alteração |
| Banca | `/banca` | Jurados, com código individual (link `banca.html?c=CODIGO`) |
| Telão | `/resultados` | Público. Mostra participação; depois de liberado, faz o anúncio |
| Painel interno | `/admin` | Organização (login). Controles, ranking completo, todos os votos, exportação |

Teste qualquer página sem tocar no banco acrescentando `?demo` (ex.: `/admin?demo`).

## Regra da nota
- Cada voto (popular ou da banca) = média de Inovar, Conectar e Transformação.
- Nota popular do pitch = média de todos os votos populares (vira uma nota só).
- Nota final (padrão) = média entre a nota popular e a nota de cada jurado
  (o público conta como mais um jurado). Alternativa no painel: 50% popular + 50% banca.

## Instalação da v2
1. **Supabase > SQL Editor:** rode `supabase/03-v2-regras-completas.sql`.
2. **Admin:** Supabase > Authentication > Users > Add user (e-mail + senha, marque Auto Confirm).
   Depois, no SQL Editor: `insert into admins (email) values ('seu.email@altoqi.com.br');`
3. **Recomendado:** Authentication > Sign In / Providers > desative "Allow new users to sign up".
4. **GitHub:** suba os arquivos desta pasta para `votacao-pitches-hackathon/votacao-pitches/`, substituindo os antigos.
5. **Jurados:** em `/admin`, cadastre cada jurado e use "Copiar link" para mandar o acesso.

## No dia
1. Antes de abrir: em `/admin`, "Zerar votação" (apaga os testes).
2. QR code no telão (`/resultados`) e nos slides.
3. Ao final: encerre a votação popular e a banca no painel.
4. Hora do anúncio: "Resultado no telão" → Liberado. No telão, `→` revela do 9º ao 1º.
5. Baixe a planilha completa no painel.

## Segurança
- Votos, e-mails e códigos da banca não são acessíveis pela API pública; só pelas funções do banco.
- O painel exige login de um e-mail cadastrado em `admins`.
- As notas só aparecem no telão depois de "Liberado".
- O e-mail não é verificado: dá para restringir ao domínio corporativo no painel.
