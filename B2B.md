# B2B — profissionais de saúde e academias

## Personas
| Persona | Dor | Oferta | Modelo |
|---|---|---|---|
| Nutricionista | paciente não registra o que come | aderência real, prescrição de plano, relatório de consulta | por profissional + faixa de pacientes |
| Médico | dados fragmentados | linha do tempo consolidada, sinais do wearable, resumo pré-consulta | assinatura profissional |
| Personal | não sabe se o treino foi executado | prescrição + execução real + progressão | por profissional + alunos |
| Academia | retenção e evasão | multi-professor, marca própria, painel de frequência | por unidade |

## Arquitetura
```
Organization (clínica/academia)
 +- Seat (profissional)  -- RBAC: owner | professional | assistant | viewer
     +- CareLink (profissional <-> paciente)
         scopes: [nutrition.read, workout.write, clinical.read, vitals.read]
         status: invited | active | paused | revoked
         expires_at
         audit_log
```

## Princípios inegociáveis
1. O dado é do paciente, não da clínica.
2. Consentimento granular e revogável a um toque, com tela de "quem vê o quê".
3. Revogação é imediata.
4. Toda leitura de dado clínico gera log visível para o paciente.
5. Painel profissional é **web, multi-tenant**, separado do app do paciente.
6. Nenhuma superfície B2B tem anúncio.
7. A IA organiza, resume e destaca. A conduta é do profissional. Disclaimer em
   todo relatório.
8. AGPL no servidor implica oferecer o código a quem usa o serviço pela rede:
   crie a rota `/source` com o tarball da versão em execução. Vende-se
   hospedagem, marca, suporte e integração — não segredo de código.
