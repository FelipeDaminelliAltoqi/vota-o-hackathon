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
      descricao: "Originalidade e eficácia da ferramenta, criatividade no uso de inteligência artificial / automações e capacidade de pensar fora da caixa para quebrar gargalos históricos." },
    { chave: "conectar", nome: "Conectar",
      descricao: "Integração multidisciplinar, fluidez ponta a ponta do processo desenhado, clareza das políticas de SLA e capacidade de conectar diferentes áreas da organização." },
    { chave: "transformar", nome: "Transformação",
      descricao: "Impacto real e mensurável nos indicadores de negócio (KPIs), viabilidade prática de colocação em produção em até 60 dias e potencial de geração de valor para a AltoQi." }
  ],

  // Setores para o votante escolher. Lista vazia = campo de texto livre.
  SETORES: [],

  // Endereço público da votação (vira o QR code no telão). Vazio = raiz do próprio site.
  URL_VOTACAO: "",

  // Os ids precisam bater com a tabela "pitches" do banco.
  PITCHES: [
    { id: 1, titulo: "Solicitação de compras e pagamentos" },
    { id: 2, titulo: "Plataforma de engajamento e desenvolvimento" },
    { id: 3, titulo: "Captação de leads para B2B Escritórios" },
    { id: 4, titulo: "Renovação automática" },
    { id: 5, titulo: "Enriquecimento inteligente da base de contatos" },
    { id: 6, titulo: "Testes com IA em aplicações desktop e web" },
    { id: 7, titulo: "Gestão da carteira de clientes governamentais" },
    { id: 8, titulo: "Fabricante 360 | Inteligência com IA" }
  ]
};
