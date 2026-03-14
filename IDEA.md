# IDEA.md — dms-wakatime

Plugin para DankMaterialShell que mostra seu tempo de código diretamente na barra,
com popout detalhado de stats. Suporta WakaTime (cloud) e self-hosted (Wakapi, Hakatime).

---

## Visão geral

O plugin aparece como uma pill discreta na DankBar. Com um clique, abre um popout
com 4 abas de estatísticas. Tudo atualiza em background sem intervenção do usuário.

---

## Bar Pill

Sempre visível, mínima:

```
⌨  5h 23m   ranqia  •  TypeScript
```

- Ícone de teclado com cor que reflete progresso da meta diária
  - 🔴 Vermelho: abaixo de 50% da meta
  - 🟡 Amarelo: entre 50% e 90%
  - 🟢 Verde: 90% ou mais
  - ⚫ Cinza: sem dados / erro
- Tempo total do dia (`5h 23m`)
- Separador `•`
- Campo configurável: projeto atual / linguagem / editor / nada
- Clique abre o popout

---

## Popout — 4 abas

### Header (fixo em todas as abas)

```
  5h 23m  ████████████░░░░  meta: 8h
```

- Tempo total do dia em destaque
- Barra de progresso proporcional à meta
- Badge discreto se self-hosted: `Wakapi` ou `Hakatime`
- Se dados desatualizados: banner `"Dados desatualizados · última atualização há Xmin"`

---

### Aba 1: Hoje

**Card "Agora"** — projeto atual em destaque:
```
  Agora: ranqia  •  TypeScript  •  Zed
  último heartbeat há 4 minutos
```

**Gráfico de atividade por hora** (barras verticais, 0h–23h):
```
  [▂▃▁▁▃▅▇█▆▄▂▁▁▁▃▅▆▄▂▁▁▁▁▁]
   0  3  6  9  12 15 18 21
```
- Cada barra = minutos de código naquela hora
- Barra mais alta destacada com cor primária

**Top 5 Projetos do dia:**
```
  ranqia    ████████████  4h 12m
  dotfiles  ████          1h 03m
  dms-waka  ██              34m
```

**Top 5 Linguagens do dia:**
```
  TypeScript  ████████████  4h 12m  67%
  Shell       ████            58m    8%
  QML         ███             34m    5%
```

---

### Aba 2: Semana

**Gráfico de 7 dias** (barras verticais, clicável):
```
  [▂▄▆█▇▃▅]
   S T Q Q S S D
```
- Barra do dia atual destacada
- Clique numa barra filtra o breakdown abaixo pro dia específico

**Resumo:**
```
  Semana: 31h 42m  •  média: 4h 31m/dia
  ↑ +2h 15m vs semana passada
  Melhor dia: Quarta  8h 12m
```

**Breakdown do período selecionado:**
- Top linguagens com barras + percentual
- Top projetos com barras + tempo

---

### Aba 3: Projetos

**Seletor de período:** `Hoje  7 dias  30 dias  6 meses`

**Lista de projetos:**
```
  ranqia          ████████████  4h 12m  [TS]  •  há 23min
  dotfiles        ████          1h 03m  [sh]  •  há 2h
  dms-wakatime    ██              34m   [QML] •  há 4h
```

**Ao clicar num projeto, expande inline:**
```
  ranqia  ↓
    TypeScript  ████████  67%
    Shell       ███       18%
    JSON        ██        10%
    Markdown    ▌          5%

    [▁▂▄▃█▃▂]  (atividade por dia no período)
    Editor: Zed  97%
```
- Um projeto expandido por vez

---

### Aba 4: Stats

**Streaks:**
```
  🔥 Streak: 7 dias  •  Recorde: 23 dias
  Dias ativos em março: 12 de 14
```

**Linguagens — últimos 30 dias:**
```
  [pie chart]   TypeScript  67%
                Shell        8%
                QML          5%
                Outros      20%
```

**Editores — últimos 30 dias:**
```
  [pie chart]   Zed    97%
                Neovim  3%
```

**Padrões de produtividade:**
```
  Dia mais produtivo: Quarta  (média 5h 12m)
  Horário de pico: 14h–17h
```

---

## Settings

### API
- **API Key** — texto, placeholder "Detectada de ~/.wakatime.cfg"
- **API URL** — texto, placeholder "https://wakatime.com/api/v1" (para Wakapi/Hakatime)
- **Botão "Testar conexão"** — faz fetch de `/users/current`, mostra toast com nome ou erro

### Meta diária
- **Horas por dia** — slider 1h–12h, step 0.5h, default 4h
- **Dias ativos** — toggles Seg Ter Qua Qui Sex Sab Dom (usados para cálculo de streak)

### Bar Pill
- **Mostrar ao lado do tempo** — seletor: Projeto / Linguagem / Editor / Nada
- **Indicador de cor da meta** — toggle

### Intervalos de atualização
- **Pill** — slider 1–10 min, default 5
- **Dados do dia** — slider 5–30 min, default 15
- **Dados da semana** — slider 15–60 min, default 30

---

## Estados especiais

| Situação | Pill | Popout |
|---|---|---|
| Sem ~/.wakatime.cfg ou api_key | `⌨ configurar` | Card de onboarding: instruções de instalação do WakaTime CLI |
| Erro de API / rede | ícone cinza + tempo do cache + ponto de aviso | Banner "Dados desatualizados" |
| 0 minutos hoje | `⌨ 0m` normal | Mensagem motivacional + breakdown da semana como fallback |
| Self-hosted detectado | normal | Badge "Wakapi" ou "Hakatime" no header |

---

## Comportamento de cache e timers

- Ao iniciar o plugin, carrega cache instantaneamente (sem tela em branco)
- `pillTimer` dispara imediatamente ao iniciar
- `todayTimer`, `weekTimer`, `monthTimer` têm delay de 10s no boot (evita sobrecarga)
- Falha de fetch: mantém cache anterior, marca como desatualizado
- Sucesso de fetch: salva no cache e atualiza UI

---

## Prioridade de implementação sugerida

1. Leitura do `.wakatime.cfg` + fetch básico + teste de conexão
2. Bar pill básico (com dados reais)
3. Aba Hoje
4. Settings completo
5. Aba Semana
6. Aba Projetos (com expand inline)
7. Aba Stats (pie charts, streaks)
8. Polish: estados especiais, animações, vertical pill
