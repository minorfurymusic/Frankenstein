# Regras que valem em todo arquivo do projeto

- Sem prova executada, o status é NÃO VERIFICADO. Cole a saída literal.
- Sem dependência proprietária (anúncio, ML Kit, Play Services, Firebase, SDK social).
- Sem chamada de rede fora da camada de sync explícita.
- Sem telemetria, analytics ou crash reporting com dado pessoal.
- Dado de saúde é sensível (LGPD): nunca sai do aparelho sem ação explícita do usuário.
- Exportação de dados nunca é paga nem limitada.
- Nenhum degrau pago é decidido no cliente. O cliente apresenta um entitlement
  assinado pelo servidor; quem valida é o servidor.
- Unidades sempre em SI. Timestamps em UTC, com timezone gravado à parte.
