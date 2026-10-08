// Configuração da votação. Edite só este arquivo.
// Para testar sem banco, acrescente ?demo na URL de qualquer página.
window.VOTACAO_CONFIG = {
  SUPABASE_URL: "https://doiaflynbljzfvyftoxg.supabase.co",
  // Chave publishable (pública por natureza). Nunca coloque aqui a secret/service_role.
  SUPABASE_ANON_KEY: "sb_publishable_PVhx-MwMuvy15SgYEhrC0A_l7K4mVcv",

  EVENTO: "Hackathon AltoQi",
  PERGUNTA: "Avalie de 0 a 5 o impacto e a viabilidade de cada apresentação de pitch:",
  ROTULO_MIN: "Baixo impacto / Precisa evoluir",
  ROTULO_MAX: "Excelente / Alto impacto",

  // Os 3 critérios avaliados pelo público e pela banca (a "chave" não muda: é o nome da coluna no banco).
  CRITERIOS: [
    { chave: "inovar", nome: "Inovar",
      descricao: "Ousadia e inconformismo para olhar o problema por outro ângulo e transformá-lo em uma solução real e fora da caixa." },
    { chave: "conectar", nome: "Conectar",
      descricao: "Visão coletiva que conecta o problema à solução e a solução ao negócio, unindo pessoas, dados e propósito." },
    { chave: "transformar", nome: "Transformar",
      descricao: "Capacidade de transformar o dia a dia, liberando tempo para o que importa e construindo um futuro inteligente." }
  ],

  // Setores para o votante escolher. Lista vazia = campo de texto livre.
  SETORES: [],

  // Endereço público da votação (vira o QR code no telão). Vazio = raiz do próprio site.
  URL_VOTACAO: "",

  // Ordem = ordem das apresentações. Os ids NÃO mudam (estão ligados aos votos e aos conflitos da banca).
  PITCHES: [
    { id: 7, titulo: "Gestão da carteira de clientes governamentais" },
    { id: 2, titulo: "Plataforma de engajamento e desenvolvimento" },
    { id: 5, titulo: "Enriquecimento inteligente da base de contatos" },
    { id: 6, titulo: "Testes com IA em aplicações desktop e web" },
    { id: 8, titulo: "Fabricante 360 | Inteligência com IA" },
    { id: 3, titulo: "Captação de leads para B2B Escritórios" },
    { id: 1, titulo: "Solicitação de compras e pagamentos" },
    { id: 4, titulo: "Renovação automática" }
  ]
};
