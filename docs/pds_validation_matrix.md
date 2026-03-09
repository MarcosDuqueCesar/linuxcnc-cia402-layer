# DS402 PDS Validation Matrix

Projeto: `linuxcnc-cia402-layer`

Este documento formaliza a validação da camada PDS (Power Drive System) no harness HAL atual.

Escopo desta matriz:

- validar decode de estados DS402 no `cia402_pds`
- validar reação do pipeline determinístico de `6040/6041`
- validar política de máquina aplicada ao PDS
- validar cenários negativos usando `cia402_stub`
- registrar comandos manuais reproduzíveis no ambiente atual

Esta matriz é baseada no harness atual:

- `machine_safety_gate`
- `cia402_pds`
- `cia402_homing`
- `cia402_cw_compose`
- `cia402_stub`

Arquivo HAL principal atual:

- `hal/stub_test_modular_pds.hal`

---

## 1. Premissas de execução

Diretório de trabalho:

```bash
cd ~/linuxcnc/configs/opc_validation
```

Harness carregado e operacional.

Condição base recomendada antes de cada teste:

```bash
halcmd sets estop-ok TRUE
halcmd sets machine-on TRUE
halcmd sets drives-ready TRUE
halcmd sets home-req FALSE
halcmd sets motion-req FALSE
halcmd sets fault-reset-req FALSE

halcmd setp pds.enable TRUE
halcmd setp pds.disable FALSE
halcmd setp pds.quick-stop FALSE
halcmd setp pds.fault-reset FALSE

halcmd setp stub.pds-sim-enable TRUE
halcmd setp stub.inject-fault FALSE
halcmd setp stub.force-ready-to-switch-on FALSE
halcmd setp stub.force-switched-on FALSE
halcmd setp stub.force-quick-stop-active FALSE
halcmd setp stub.force-fault-reaction-active FALSE
```

Diagnóstico principal durante os testes:

```bash
halcmd show pin msg
halcmd show pin pds
halcmd show pin ut
halcmd show pin stub
```

Sinais principais a observar:

- `msg.machine-ok`
- `msg.allow-enable`
- `msg.allow-homing`
- `msg.allow-fault-reset`
- `pds.state`
- `pds.reason`
- `pds.fault`
- `pds.op-enabled`
- `pds.cw-pds`
- `pds.st-6f`
- `pds.st-4f`
- `stub.out-statusword`

---

## 2. Referência de estados e reasons do PDS

Estados observados no `cia402_pds`:

| Estado lógico | Valor esperado |
|---|---:|
| Switch On Disabled | 64 |
| Ready To Switch On | 33 |
| Switched On | 35 |
| Operation Enabled | 39 |
| Quick Stop Active | 7 |
| Fault Reaction Active | 15 |
| Fault | 8 |

Reasons atuais do `cia402_pds`:

| Reason | Significado |
|---:|---|
| 0 | `PDS_R_NOT_READY` |
| 1 | `PDS_R_SWITCH_ON_DISABLED` |
| 2 | `PDS_R_READY_TO_SWITCH_ON` |
| 3 | `PDS_R_SWITCHED_ON` |
| 4 | `PDS_R_OPERATION_ENABLED` |
| 5 | `PDS_R_QUICK_STOP_ACTIVE` |
| 6 | `PDS_R_FAULT_REACTION_ACTIVE` |
| 10 | `PDS_R_FAULT_PRESENT` |
| 11 | `PDS_R_FAULT_RESET_REQUESTED` |
| 12 | `PDS_R_FAULT_RESET_BLOCKED` |
| 20 | `PDS_R_UNKNOWN_STATE` |

Máscaras de decode implementadas:

- `st_6f = sw & 0x006F`
- `st_4f = sw & 0x004F`

---

## 3. Matriz de validação PDS

### PDS-001 — Switch On Disabled por política de máquina

**Objetivo**  
Confirmar que `machine_safety_gate` bloqueia enable quando `machine-on = FALSE` e o PDS permanece em SOD.

**Preparação**

```bash
halcmd sets machine-on FALSE
halcmd show pin msg
halcmd show pin pds
```

**Esperado**

- `msg.allow-enable = FALSE`
- `msg.machine-ok = FALSE`
- `pds.cw-pds = 0x0000`
- `pds.state = 64`
- `pds.reason = 1`
- estado coerente com `Switch On Disabled`

**Resultado de referência já observado**

- `state = 64`
- `reason = 1`
- `sw = 0x0260`

---

### PDS-002 — Retorno a enable permitido por política

**Objetivo**  
Confirmar que a política permite progressão do PDS quando `machine-on = TRUE`.

**Preparação**

```bash
halcmd sets machine-on TRUE
halcmd show pin msg
halcmd show pin pds
```

**Esperado**

- `msg.allow-enable = TRUE`
- `msg.machine-ok = TRUE`
- `pds.cw-pds = 0x000F` ou progressão compatível com enable ativo
- `pds.state = 39`
- `pds.reason = 4`

**Resultado de referência já observado**

- `state = 39`
- `reason = 4`
- `sw = 0x0237`

---

### PDS-003 — Ready To Switch On via stub forçado

**Objetivo**  
Validar decode de `Ready To Switch On` com injeção explícita do stub.

**Preparação**

```bash
halcmd setp stub.force-ready-to-switch-on TRUE
halcmd show pin pds
```

**Esperado**

- `pds.state = 33`
- `pds.reason = 2`
- `pds.st-6f = 0x0021`

**Encerramento**

```bash
halcmd setp stub.force-ready-to-switch-on FALSE
```

---

### PDS-004 — Switched On via stub forçado

**Objetivo**  
Validar decode de `Switched On` com injeção explícita do stub.

**Preparação**

```bash
halcmd setp stub.force-switched-on TRUE
halcmd show pin pds
```

**Esperado**

- `pds.state = 35`
- `pds.reason = 3`
- `pds.st-6f = 0x0023`

**Encerramento**

```bash
halcmd setp stub.force-switched-on FALSE
```

---

### PDS-005 — Operation Enabled nominal

**Objetivo**  
Confirmar o estado nominal `Operation Enabled` no harness.

**Preparação**

```bash
halcmd show pin pds
```

**Esperado**

- `pds.state = 39`
- `pds.reason = 4`
- `pds.op-enabled = TRUE`
- `pds.st-6f = 0x0027`
- `stub.out-statusword = 0x0237` ou equivalente coerente

---

### PDS-006 — Quick Stop Active via stub forçado

**Objetivo**  
Validar decode de `Quick Stop Active`.

**Preparação**

```bash
halcmd setp stub.force-quick-stop-active TRUE
halcmd show pin pds
```

**Esperado**

- `pds.state = 7`
- `pds.reason = 5`
- `pds.op-enabled = FALSE`
- `pds.st-6f = 0x0007`

**Encerramento**

```bash
halcmd setp stub.force-quick-stop-active FALSE
```

---

### PDS-007 — Fault Reaction Active via stub forçado

**Objetivo**  
Validar decode de `Fault Reaction Active`.

**Preparação**

```bash
halcmd setp stub.force-fault-reaction-active TRUE
halcmd show pin pds
```

**Esperado**

- `pds.state = 15`
- `pds.reason = 6`
- `pds.op-enabled = FALSE`
- `pds.st-6f = 0x000F`

**Encerramento**

```bash
halcmd setp stub.force-fault-reaction-active FALSE
```

---

### PDS-008 — Fault via injeção de falha

**Objetivo**  
Validar decode de `Fault` usando `stub.inject-fault`.

**Preparação**

```bash
halcmd setp stub.inject-fault TRUE
halcmd show pin pds
```

**Esperado**

- `pds.state = 8`
- `pds.reason = 10`
- `pds.fault = TRUE`
- `pds.op-enabled = FALSE`
- `pds.st-6f = 0x0008`

**Encerramento**

```bash
halcmd setp stub.inject-fault FALSE
```

---

### PDS-009 — Fault reset bloqueado por política

**Objetivo**  
Confirmar que reset de fault não progride se a política não permitir.

**Preparação**

Primeiro entre em fault:

```bash
halcmd setp stub.inject-fault TRUE
halcmd show pin pds
```

Depois bloqueie a política:

```bash
halcmd sets machine-on FALSE
halcmd setp pds.fault-reset TRUE
halcmd sets fault-reset-req TRUE
halcmd show pin msg
halcmd show pin pds
```

**Esperado**

- `msg.allow-fault-reset = FALSE`
- `pds.reason = 12`
- fault não limpa
- `pds.state` permanece em fault ou sem retorno para OE

**Encerramento**

```bash
halcmd setp pds.fault-reset FALSE
halcmd sets fault-reset-req FALSE
halcmd setp stub.inject-fault FALSE
```

---

### PDS-010 — Fault reset permitido por política

**Objetivo**  
Confirmar handshake completo de fault reset.

**Preparação**

Entrar em fault:

```bash
halcmd setp stub.inject-fault TRUE
halcmd show pin pds
```

Permitir reset:

```bash
halcmd sets machine-on TRUE
halcmd sets estop-ok TRUE
halcmd sets drives-ready TRUE
halcmd setp pds.fault-reset TRUE
halcmd sets fault-reset-req TRUE
halcmd show pin msg
halcmd show pin pds
```

Aguardar o delay configurado no stub e inspecionar novamente:

```bash
halcmd show pin pds
```

**Esperado**

- `msg.allow-fault-reset = TRUE`
- transição por `PDS_R_FAULT_RESET_REQUESTED`
- fault limpa após `stub.fault-reset-delay-cycles`
- retorno para `SOD` e posteriormente progressão normal até `OE`

**Encerramento**

```bash
halcmd setp pds.fault-reset FALSE
halcmd sets fault-reset-req FALSE
halcmd setp stub.inject-fault FALSE
```

---

### PDS-011 — Drives not ready bloqueando política

**Objetivo**  
Confirmar que política da máquina bloqueia enable quando backend não está pronto.

**Preparação**

```bash
halcmd sets drives-ready FALSE
halcmd show pin msg
halcmd show pin pds
```

**Esperado**

- `msg.machine-ok = FALSE`
- `msg.allow-enable = FALSE`
- `msg.reason = 12` no `machine_safety_gate`
- `pds` não alcança `Operation Enabled`

**Encerramento**

```bash
halcmd sets drives-ready TRUE
```

---

### PDS-012 — E-stop bloqueando política

**Objetivo**  
Confirmar que política da máquina bloqueia enable sob E-stop.

**Preparação**

```bash
halcmd sets estop-ok FALSE
halcmd show pin msg
halcmd show pin pds
```

**Esperado**

- `msg.machine-ok = FALSE`
- `msg.allow-enable = FALSE`
- `msg.reason = 10` no `machine_safety_gate`
- `pds.cw-pds = 0x0000` ou comportamento equivalente de bloqueio

**Encerramento**

```bash
halcmd sets estop-ok TRUE
```

---

## 4. Casos complementares recomendados

Os testes abaixo não são obrigatórios para fechar a etapa PDS, mas são úteis para robustez adicional.

### PDS-013 — Verificação do estado inicial do stub

```bash
halcmd setp stub.pds-sim-enable TRUE
halcmd setp stub.pds-initial-state 0
halcmd show param stub
```

Objetivo:

- confirmar previsibilidade do estado inicial do simulador
- facilitar scripts automatizados futuros

### PDS-014 — Delay de transição do stub

```bash
halcmd setp stub.pds-transition-delay-cycles 20
halcmd show param stub
```

Observação:

No código atual do stub, este parâmetro está mantido por compatibilidade e hoje não governa uma máquina temporal completa de transição no modo imediato. Portanto, ele pode permanecer documentado como compatibilidade, mas não deve ser tratado como cobertura temporal plena de transição PDS.

---

## 5. Critério de fechamento da etapa PDS

A etapa de validação PDS pode ser considerada formalmente fechada quando os seguintes pontos estiverem confirmados no harness:

- SOD validado
- RTSO validado
- SO validado
- OE validado
- QSA validado
- FRA validado
- FAULT validado
- fault reset bloqueado validado
- fault reset permitido validado
- política de máquina validada para `machine-on`, `estop-ok` e `drives-ready`
- nenhuma ambiguidade de writer no `6040`

---

## 6. Observação importante sobre o stub

O `cia402_stub` atual contém recursos que vão além da validação PDS. Ele já possui instrumentação muito útil para a próxima etapa de robustez de homing:

- `inhibit-mode-ack`
- `inhibit-home-done`
- `freeze-home-progress`
- `force-mode-drop`
- `forced-opmode-value`

Esses controles permitem simular:

- drive que não confirma `6061`
- drive que inicia homing mas nunca conclui
- drive sem progresso observável
- drive que perde o modo 6 durante o procedimento
- drive que “mente” ou muda o `6061` em runtime

Isso é extremamente valioso para validar o `cia402_homing` robusto sem hardware real.

---

## 7. Próximo passo após fechamento desta matriz

Depois do fechamento formal da PDS Validation Matrix, o próximo passo natural é criar a matriz equivalente para homing robusto, cobrindo:

- mode timeout
- done timeout
- progress watchdog
- mode lost
- completion normal

Arquivo sugerido para a próxima etapa:

- `docs/homing_validation_matrix.md`

