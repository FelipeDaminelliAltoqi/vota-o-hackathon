# Votação dos pitches · Hackathon AltoQi (v3)

| Página | Endereço | Para quem |
|---|---|---|
| Votação (público e banca) | `/` | Todos. E-mail → setor (público) ou código (banca) |
| Link pessoal do jurado | `/?c=CODIGO` | Banca, entra direto (botão "Copiar link" no painel) |
| Telão | `/resultados` | Projetor: status de cada pitch, participação e anúncio |
| Painel interno | `/admin` | Organização (login Supabase) |

`?demo` em qualquer endereço = dados simulados, nada vai para o banco.

## Regras
- Público: só vota no pitch com votação **liberada** no painel; 1 voto por e-mail por pitch, sem alteração.
- Banca: vota a qualquer momento em todos os pitches, exceto o do seu conflito de interesse; pode alterar as notas.
- Nota de cada voto = média de Inovar, Conectar e Transformar.
- Final = média entre a nota popular (vale 1 nota) e a nota de cada jurado. Ex.: 8 jurados + popular = média de 9 notas.

## Instalação da v3
1. Supabase > SQL Editor: rode `supabase/04-v3-liberacao-por-equipe-e-banca.sql` (depois do 03).
2. GitHub: substitua os arquivos da pasta do site por estes.
3. `/admin` > Banca: confira os 11 jurados, conflitos e copie o link de cada um.

## No dia
1. `/admin` > Zerar votação (apaga testes, todos os pitches voltam para "aguardando").
2. Depois de cada apresentação: "Liberar votação" do pitch. Ao fim do tempo: "Encerrar votação".
3. Anúncio: "Resultado no telão" → Liberado. No telão, `→` revela do 8º ao 1º.
