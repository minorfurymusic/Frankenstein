# ADR-13 — Login com Google obrigatório

**Status:** aceito na parte de produto (decisão explícita do usuário,
2026-10-02); **mecanismo técnico em aberto** — decidir na fase do servidor.
Altera `docs/MONETIZACAO.md` ("grátis sem cadastro") e ADR-7 (fluxo "Já assinei").
**Data:** 2026-10-02

> **Atualização (2026-10-02, usuário):** o login entra **quando começarem os
> testes das telas**, não no fim do projeto. O servidor continua em aberto —
> o usuário volta a esse assunto mais tarde. Como o mecanismo técnico
> (seção "Opções") depende de servidor ou de exceção à regra de licença,
> essa escolha vira portão no início da rodada de testes.

## Contexto

Até aqui o projeto prometia o degrau grátis "sem conta, sem cadastro"
(`docs/MONETIZACAO.md:8-11`), e a ADR-7 resolvia a assinatura sem login, com
e-mail + código de uso único. Em 2026-10-02 o usuário decidiu: o app terá
**login com Google obrigatório**, feito **pelo navegador, sem Google Play
Services** (para manter `.claude/rules/licenca.md` e a publicação no F-Droid).

## Achado técnico (verificado em 2026-10-02, por busca — a página oficial do Google está bloqueada pela rede deste ambiente)

- O Google **desativou por padrão** o redirecionamento por esquema
  customizado (`app://callback`) para clientes OAuth Android novos, por risco
  de um app se passar por outro. A recomendação do Google é o SDK Google
  Identity Services, que depende do Play Services — proibido aqui.
  Fontes: blog de desenvolvedores do Google ("Improving user safety in OAuth
  flows through new OAuth Custom URI scheme restrictions") e a página de
  ajuda "Setting up OAuth 2.0", via busca.
- A alternativa sem Play Services é um redirecionamento `https` para um
  domínio nosso, verificado como App Link do app. Na prática (AppAuth-Android,
  issue #784) as Custom Tabs nem sempre entregam esse link ao app, e o tipo
  de cliente que aceita `https` (cliente Web) espera a troca do código num
  servidor, com segredo que não pode ficar dentro do APK.

Conclusão: **login com Google sem Play Services, no Android hoje, depende de
um domínio e de um servidor nosso** para concluir a troca do código.

## Opções (para a fase do servidor)

1. **Troca do código no servidor nosso.** Navegador → Google → nosso
   domínio → servidor troca o código → devolve uma sessão ao app por App
   Link. Mantém a regra de licença. Depende do servidor (planejado para o
   fim) e de um domínio.
2. **Exceção à regra de licença só para o login** (SDK do Google com Play
   Services). Login mais simples e nativo, mas exige revogar
   `.claude/rules/licenca.md` para esse caso e tira o app do F-Droid.

## Decisão

- **Produto:** login com Google obrigatório. O layout (Claude Design) já
  desenha a tela de entrada e a conta.
- **Implementação:** fica junto com o servidor (final do projeto), escolhendo
  entre as opções 1 e 2 nesse momento. Até lá o app é construído e testado
  sem login — nada do resto depende dele.

## Consequências

- **Fica mais fácil:** assinatura amarrada à conta Google (substitui o
  código de "Já assinei" da ADR-7 quando o servidor existir); trocar de
  celular sem perder vínculo.
- **Fica mais difícil:** primeira abertura do app exige internet (até aqui
  o app nunca exigia — `CLAUDE.md` regra 7); o projeto passa a ser
  controlador de dados pessoais (nome, e-mail) na LGPD desde o primeiro
  usuário — precisa de política de privacidade e de "excluir conta".
  Depois do primeiro login, o app continua funcionando offline.
- **Passa a ser obrigatório:** tela de excluir conta e dados; política de
  privacidade antes de publicar.
- **Não muda:** dado de saúde continua no aparelho. Login identifica a
  pessoa; não envia histórico de saúde a lugar nenhum por si só.
