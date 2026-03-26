# Taxonomia de profiles

A distribuição de profiles passa a seguir três superfícies explícitas:

- `validated/` → profiles já validados no framework real anexado ao repositório
- `reference/` → profiles de referência para integração com drive real, derivados de manual, sem alterar core
- `experimental/` → profiles ainda não fechados, incluindo casos como gantry

Regras:

1. Um profile não introduz lógica.
2. Um profile não altera pipeline.
3. Um profile não redefine semântica.
4. Um profile não adapta o framework ao drive.
5. Um profile apenas declara contrato de integração, mapeamento e escalas.
