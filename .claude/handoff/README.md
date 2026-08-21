# Handoff entre sessões

Estado de trabalho, não documentação.

- **`latest.md`** — onde a última sessão parou. É a primeira coisa que a skill
  `godot-session-setup` lê ao ser invocada. Sobrescrito a cada gravação.
- **`archive/`** — versões anteriores, nomeadas `AAAA-MM-DD-HHMM-<card-ou-tema>.md`.
  O `latest.md` é movido para cá antes de ser sobrescrito.

## O que vai aqui e o que não vai

| Vai | Não vai |
|---|---|
| O que ficou pela metade | Conhecimento durável do projeto → `AGENTS.md` |
| Portões quebrados e por quê | Escopo de trabalho → um card em `Cards/` |
| Decisões ainda não migradas | O que já está no histórico do git |
| Próximo passo concreto | Narrativa do que foi feito passo a passo |

A parte mais valiosa do arquivo é a seção **"Pela metade / não verificado"**. Um
handoff que só lista vitórias é pior que nenhum: a próxima sessão assume que está
tudo pronto e constrói em cima.

## Por que é versionado

O projeto é trabalhado de 3 máquinas. Deixar o handoff fora do git faria o
estado ficar preso a um computador — exatamente o problema que ele existe para
resolver.

Datas sempre absolutas. "Ontem" não significa nada para quem lê depois.

## Nunca dado pessoal

O repositório é público. Um handoff que precise citar um caso concreto de aluno
ou docente usa matrícula/nome fictícios — a regra do `AGENTS.md` ("Nada de nome
real de pessoa em arquivo versionado") vale aqui também.
