# ADR-7 — Canais de distribuição e meios de pagamento

**Status:** aceito
**Data:** 2026-08-05 (revisão 3 — dois complementos pedidos antes do aceite)

## Nota de revisão 3

Dois complementos pedidos antes de aceitar:

1. **Como o entitlement chega ao app depois da compra no site.** A
   revisão 2 decidiu a Opção 4 (sem interface de pagamento no app) mas
   não definiu o elo que fecha o fluxo — sem isso, "implementável hoje"
   era retórica, não mecanismo. Definido abaixo, e conversado com o "sem
   cadastro" de `docs/MONETIZACAO.md:8-11`.
2. **"Proibido qualquer menção" trocado por regra utilizável.** A versão
   anterior proibia até indicar que um recurso é pago, o que deixa o app
   sem forma de comunicar "isso é Premium" para quem já não é assinante —
   inutilizável na prática. Substituído por um limite específico.

## Contexto

(sem alteração da revisão 2) `docs/MONETIZACAO.md:47-56` lista os 4
canais candidatos e pede para confirmar regras de loja e citar fonte —
feito via `WebSearch`, ressalva de método mantida no fim. Google Play e
Apple abriram link de pagamento externo por decisão judicial em 2026,
mas a aplicação ao Brasil não está confirmada com a mesma força que
EUA/UE/UK. **Ligação com ADR-5 (revisão 2):** cliente Apache-2.0, o
risco de conflito de licença com a App Store não se aplica mais ao
cliente.

## Como o entitlement chega ao app (o elo que faltava)

**Não há login tradicional, mas há identidade mínima — só para quem
paga.** `docs/MONETIZACAO.md:9` promete "sem cadastro" para o degrau
GRÁTIS — isso continua intacto, o fluxo abaixo nunca roda pra quem não
assina. Premium/B2B já pressupõe alguma identidade
(`Subscription: user_id, ...`, `docs/MONETIZACAO.md:34`) — impossível
vincular uma compra a um entitlement sem *algum* identificador. A
diferença entre isso e "cadastro" no sentido que `docs/MONETIZACAO.md`
rejeita: sem senha, sem sessão persistente de conta, sem exigir nada de
quem nunca paga.

**Fluxo:**

1. Compra no site: Pix, cartão ou boleto. Site pede e-mail (já
   necessário para recibo/nota fiscal — não é dado novo). Confirmação
   por webhook, já no design existente (`docs/MONETIZACAO.md:42`).
2. Site ativa a `Subscription` vinculada a esse e-mail e mostra, na tela
   de sucesso, um **código de vínculo** de uso único (curto, validade
   de ~15 minutos) — não é senha, é uma chave de resgate.
3. No app: tela "Já assinei" — **sem preço, sem nome de plano, sem
   menção de onde comprar** — só os dois campos: e-mail e código.
4. Uma única chamada de rede, só nesse momento, disparada por ação
   explícita do usuário (`CLAUDE.md` regra 7: "Nada de rede sem ação
   explícita"): troca e-mail + código pelo `Entitlement` assinado
   (`docs/MONETIZACAO.md:38-40`, Ed25519).
5. App guarda o entitlement localmente. Validação depois é 100% offline
   (assinatura + `exp`) — reforça a graça offline já decidida
   (`docs/MONETIZACAO.md:43`: vale até `exp` + 7 dias sem rede). Sem
   sessão de login persistente: o app não "loga" no sentido tradicional,
   só troca um código por um documento assinado e guarda o documento.
6. Código expirado ou perdido: botão "reenviar código" na mesma tela,
   novo e-mail, sem senha.

**Por que isso não vira "menção a pagamento" para efeito de política de
loja:** a tela "Já assinei" não vende nada, não mostra preço, não linka
para o site de compra — ela só troca uma credencial de uso único por um
documento. É mais perto de "restaurar compra"/"entrar", que lojas
tratam diferente de fluxo de venda, do que de um link de checkout. **Isto
é leitura minha, não confirmação de política** — mesma ressalva de
método desta ADR inteira.

## Opções consideradas

(sem alteração da revisão 2 — reproduzido para contexto)

1. Web como canal primário de pagamento, lojas como distribuição que
   apontam para o checkout quando a política permitir.
2. Billing nativo de cada loja como primário.
3. F-Droid/APK direto como canal principal.
4. Nenhuma interface de pagamento no app — decidida na revisão 2, mantida.

## Decisão

**Opção 4, com o mecanismo de vínculo acima fechando o fluxo, mais a
Opção 1 como evolução condicional — mantido da revisão 2.**

- App não vende nada dentro de si. Assinatura só no site.
- Vínculo do entitlement ao app: fluxo de e-mail + código de uso único
  descrito acima — não é conta, é resgate.
- Distribuição multi-canal (Google Play, App Store, F-Droid, APK
  direto) sem nenhuma delas precisar de tratamento especial de billing.
- Evolução condicional (não decidida agora): link de checkout dentro do
  app quando a política de link externo for confirmada para o Brasil.

**Isto está aceito.**

## Regra de comunicação de plano — substituindo a proibição anterior

A versão anterior proibia "qualquer menção a preço, assinatura ou link
de pagamento", o que também bloquearia o app de dizer que um recurso é
pago — inutilizável. Regra que substitui, **limite conservador que eu
escolhi, não leitura confirmada de política de loja**:

**Permitido:** indicar que um recurso não está disponível no plano atual
do usuário (ex.: um selo "Premium" num recurso bloqueado, ou uma tela
que diz "Este recurso não está disponível no seu plano atual").

**Proibido, sempre, dentro do app:**
- Preço, valor, ou qualquer número monetário.
- Link clicável para comprar, assinar, ou "saiba mais sobre planos".
- Texto que diga onde comprar ("no nosso site", "em breve no app"),
  mesmo sem link.

A diferença: dizer "isso é Premium" descreve um estado do produto; dizer
"assine por R$20 no nosso site" é venda. A linha entre os dois não foi
testada contra política real de nenhuma loja — é o limite que este
projeto escolhe respeitar por precaução, não uma zona confirmada como
segura.

## Consequências

- **Fica mais fácil:** zero dependência de confirmar regras de loja para
  o Brasil antes de lançar. O produto tem como comunicar "isso é
  Premium" sem ficar mudo sobre o próprio modelo de negócio.
- **Fica mais difícil:** conversão pior (fricção de sair do app);
  manter o fluxo de vínculo por e-mail+código como superfície própria
  (rate limiting contra força bruta do código de 15 min, reenvio,
  expiração) — trabalho de backend real, não é grátis de implementar.
- **Passa a ser proibido:** preço, link de compra, ou texto de onde
  comprar dentro do app — substituindo a proibição-tudo anterior por
  esse limite específico.

## Não verificado

(mantido da revisão 2, mais um item)

- Se a política de link externo já vale para o Brasil hoje — relevante
  só para a evolução condicional.
- Percentuais de taxa — idem.
- Onde fica a linha entre "estado do plano" e "venda" na prática de cada
  loja — registrado como limite conservador acima, não testado.
- **Novo:** se um fluxo de "restaurar assinatura por e-mail+código" é
  tratado por alguma loja como equivalente a um mecanismo de pagamento
  alternativo só por trocar uma credencial por direito de acesso — não
  encontrei política que trate isso especificamente; é a leitura mais
  razoável que tenho, não confirmação.

## Ressalva de método

Toda a pesquisa desta ADR foi via `WebSearch`. Antes de implementar a
evolução condicional (Opção 1), reconfirme lendo a documentação oficial
diretamente. O mecanismo de vínculo (seção acima) é decisão de produto
própria do Frankstein, não depende de política de loja para funcionar.
