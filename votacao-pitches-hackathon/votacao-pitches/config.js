// Configuração da votação. Edite só este arquivo.
// Para testar sem banco, troque SUPABASE_URL por "https://SEU-PROJETO.supabase.co" (modo demonstração).
window.VOTACAO_CONFIG = {
  SUPABASE_URL: "https://doiaflynbljzfvyftoxg.supabase.co",
  // Chave publishable (pública por natureza). Nunca coloque aqui a secret/service_role.
  SUPABASE_ANON_KEY: "sb_publishable_PVhx-MwMuvy15SgYEhrC0A_l7K4mVcv",

  EVENTO: "Votação dos pitches",
  PERGUNTA: "Avalie de 0 a 5 o impacto e a viabilidade de cada apresentação de pitch:",
  ROTULO_MIN: "Baixo impacto / Precisa evoluir",
  ROTULO_MAX: "Excelente / Alto impacto",

  // Endereço público da página de votação (vira o QR code no telão).
  // Vazio = usa a raiz do próprio site (ex.: https://seu-site.netlify.app/).
  URL_VOTACAO: "",

  // Os ids precisam bater com a tabela "pitches" do schema.sql.
  PITCHES: [
    { id: 1, titulo: "Solicitação de compras e pagamentos" },
    { id: 2, titulo: "Plataforma de engajamento e desenvolvimento" },
    { id: 3, titulo: "Captação de leads para B2B Escritórios" },
    { id: 4, titulo: "Renovação automática" },
    { id: 5, titulo: "Enriquecimento inteligente da base de contatos" },
    { id: 6, titulo: "Testes com IA em aplicações desktop e web" },
    { id: 7, titulo: "Gestão da carteira de clientes governamentais" },
    { id: 8, titulo: "Fabricante 360 | Inteligência com IA" },
    { id: 9, titulo: "Ferramenta Delivery para as nossas soluções" }
  ]
};
