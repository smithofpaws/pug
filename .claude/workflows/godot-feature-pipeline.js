export const meta = {
  name: 'godot-feature-pipeline',
  description: 'Entrega um card do PUG: design, TDD, portao automatizado, review em laco e smoke test com PNG.',
  whenToUse: 'Quando um card em Cards/ esta com status ready e o dev pediu para executa-lo. Passe args: { cardId: "0001-slug" }. Para rodar numa worktree, passe tambem root: o caminho absoluto dela — sem isso a execucao grava no checkout principal.',
  phases: [
    { title: 'Design', detail: 'le o card e escreve spec.md com contrato tipado e mapeamento AC-prova' },
    { title: 'Implement', detail: 'TDD: teste vermelho, implementacao minima, verde' },
    { title: 'Gate', detail: 'guardrails.py + suite GUT + parser do Godot' },
    { title: 'Review', detail: 'LGPD, contratos de dados, regressao, cobertura de AC' },
    { title: 'Fix', detail: 'aplica so os findings bloqueantes' },
    { title: 'Smoke', detail: 'roda o programa e captura PNG por AC visual' },
  ],
}

// O args as vezes chega como *string* JSON em vez de objeto, dependendo de como
// o invocador serializa (aprendido no 3d World: uma vez o cardId virou o JSON
// inteiro, outra o args.root virou undefined e a execucao de worktree gravou no
// checkout principal). Normalizar uma vez, aqui, e a unica forma de o resto do
// script poder confiar no que le.
//
// Tres formas aceitas: objeto (o caso normal), string JSON (o bug) e o id cru
// como string, que e a forma antiga documentada no whenToUse.
const input = (() => {
  if (args && typeof args === 'object') return args
  if (typeof args !== 'string') return {}
  try {
    const parsed = JSON.parse(args)
    return (parsed && typeof parsed === 'object') ? parsed : { cardId: args }
  } catch (_) {
    return { cardId: args }
  }
})()

// Caminhos absolutos: as skills sao passadas por caminho no prompt, nao por
// disparo automatico. Skill dispara por casamento de descricao, e num pipeline
// deterministico isso seria cara ou coroa.
//
// A raiz vem de input.root quando informada, e so entao dois cards podem rodar
// em paralelo em worktrees diferentes: e ela que decide onde o spec.md, o codigo
// e os PNGs de smoke sao gravados. O default preserva quem chama sem args.
// Nao ha process.cwd() aqui — o script roda sem acesso a API do Node.
const ROOT = input.root || 'O:/OneDrive/Unipampa/Coordenacao/Programas/Auxiliar de Coordenacao GD4'
const SKILLS = ROOT + '/.claude/skills'
const SKILL_DESIGN = SKILLS + '/godot-feature-design/SKILL.md'
const SKILL_DEV = SKILLS + '/godot-gdscript-dev/SKILL.md'
const SKILL_REVIEW = SKILLS + '/godot-code-review/SKILL.md'
const SKILL_SMOKE = SKILLS + '/godot-smoke-test/SKILL.md'

const MAX_ROUNDS = 3

const SPEC_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['layers', 'contracts', 'ac_mapping', 'spec_path'],
  properties: {
    spec_path: { type: 'string', description: 'Caminho do spec.md gravado' },
    layers: { type: 'array', items: { type: 'string' } },
    contracts: {
      type: 'array',
      description: 'Assinaturas publicas novas ou alteradas, ja tipadas',
      items: { type: 'string' },
    },
    ac_mapping: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['ac', 'method', 'where'],
        properties: {
          ac: { type: 'string' },
          method: { type: 'string', enum: ['headless', 'smoke', 'manual'] },
          where: { type: 'string' },
        },
      },
    },
    data_contract_risk: { type: 'string' },
  },
}

const GATE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['guardrails_clean', 'tests_passed', 'parser_clean'],
  properties: {
    guardrails_clean: { type: 'boolean' },
    tests_passed: { type: 'boolean' },
    parser_clean: { type: 'boolean' },
    output: { type: 'string', description: 'Trecho relevante da saida em caso de falha' },
  },
}

const REVIEW_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['findings', 'verdict'],
  properties: {
    verdict: { type: 'string', enum: ['clean', 'changes_required'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['file', 'line', 'blocking', 'summary', 'failure_scenario', 'fix'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          severity: { type: 'string', enum: ['low', 'medium', 'high'] },
          blocking: { type: 'boolean' },
          summary: { type: 'string' },
          failure_scenario: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
  },
}

const SMOKE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['smoke_passed', 'log_clean', 'ac_results'],
  properties: {
    smoke_passed: { type: 'boolean' },
    log_clean: { type: 'boolean' },
    ac_results: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['ac', 'method', 'verdict'],
        properties: {
          ac: { type: 'string' },
          method: { type: 'string', enum: ['headless', 'smoke', 'manual'] },
          verdict: { type: 'string', enum: ['passed', 'failed', 'not_verified'] },
          evidence: { type: 'string' },
        },
      },
    },
    notes: { type: 'string' },
  },
}

const cardId = input.cardId || null
if (!cardId) {
  throw new Error('godot-feature-pipeline: passe args: { cardId: "NNNN-slug" }')
}
const cardDir = ROOT + '/Cards/' + cardId

// Contexto comum. Os portoes sao comandos reais, ja verificados neste projeto —
// nenhum agente deve inventar uma variante.
const CONTEXT = [
  'Projeto: PUG (Pacote de Utilidades para Graduacao), Godot 4.7, GL Compatibility.',
  'Raiz: ' + ROOT + '.',
  'Convencoes: AGENTS.md (arquitetura, LGPD, multi-curso) e FORMATACAO.md (estilo).',
  'Card: ' + cardDir + '/card.md',
  '',
  'LGPD — regra absoluta: o repositorio e PUBLICO. Nenhum dado pessoal real em',
  'arquivo versionado (card, spec, teste, fixture, PNG de smoke). dados/ e leitura',
  'proibida para agentes; fixtures ficticias moram em test/fixtures/.',
  '',
  'Portoes (comandos exatos, nao improvise variantes):',
  '  python .tools/guardrails.py            # gdlint + regras do projeto (baseline/catraca)',
  '  python .tools/run_tests.py             # suite GUT headless',
  '  "C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit',
  'O --check-only isolado gera falso positivo (autoloads nao resolvem). Nao use.',
].join('\n')

log('Card ' + cardId + ': iniciando pipeline')

// ---------------------------------------------------------------- Design ----
phase('Design')
const spec = await agent(
  [
    'Leia PRIMEIRO a skill de design em ' + SKILL_DESIGN + ' e siga-a.',
    '',
    CONTEXT,
    '',
    'Tarefa: transformar o card em spec executavel e grava-la em ' + cardDir + '/spec.md.',
    'Nao escreva codigo de producao nem testes nesta fase.',
    'Todo AC do card precisa aparecer no mapeamento AC -> prova. Um AC sem prova e um',
    'card que vai fechar sem estar pronto.',
  ].join('\n'),
  { label: 'design:' + cardId, phase: 'Design', schema: SPEC_SCHEMA },
)

if (!spec) {
  throw new Error('godot-feature-pipeline: a fase de design nao retornou spec')
}
log('Spec pronta: ' + spec.contracts.length + ' contrato(s), ' + spec.ac_mapping.length + ' AC(s) mapeado(s)')

// ------------------------------------------------------------- Implement ----
phase('Implement')
await agent(
  [
    'Leia PRIMEIRO a skill de implementacao em ' + SKILL_DEV + ' e siga-a.',
    '',
    CONTEXT,
    'Spec: ' + cardDir + '/spec.md',
    '',
    'Tarefa: implementar a spec sob TDD — teste vermelho, implementacao minima, verde,',
    'refactor. Escreva teste APENAS para a camada testavel headless descrita na skill;',
    'nao fabrique teste para modulos de cena (scenes/Modulos/, scenes/Complementares/,',
    'main.gd, barraprincipal.gd) nem para caminhos de rede/UI.',
    'Ao terminar, rode os tres portoes acima e so entao reporte.',
  ].join('\n'),
  { label: 'implement:' + cardId, phase: 'Implement', model: 'sonnet' },
)

// -------------------------------------------------- Gate / Review / Fix ----
let round = 0
let lastReview = null
let lastGate = null

while (round < MAX_ROUNDS) {
  round += 1

  lastGate = await agent(
    [
      CONTEXT,
      '',
      'Tarefa: rodar os tres portoes, nesta ordem, e reportar o resultado literal.',
      '  1. python .tools/guardrails.py',
      '  2. python .tools/run_tests.py',
      '  3. "C:/Program Files/Godot/Godot_console.exe" --headless --path . --editor --quit',
      'Nao conserte nada. Voce e o medidor, nao o consertador.',
      'Em caso de falha, inclua em `output` o trecho da saida que mostra a causa.',
    ].join('\n'),
    { label: 'gate:r' + round, phase: 'Gate', model: 'sonnet', effort: 'low', schema: GATE_SCHEMA },
  )

  const gateOk = lastGate
    && lastGate.guardrails_clean && lastGate.tests_passed && lastGate.parser_clean

  lastReview = await agent(
    [
      'Leia PRIMEIRO a skill de review em ' + SKILL_REVIEW + ' e siga-a.',
      '',
      CONTEXT,
      'Spec: ' + cardDir + '/spec.md',
      'Rodada de review: ' + round + ' de ' + MAX_ROUNDS + '.',
      '',
      'Revise a mudanca inteira. Rode `git add -N .` ANTES de `git diff HEAD`: os',
      'testes novos sao arquivos nao rastreados e ficariam invisiveis no diff — e sao',
      'exatamente o que o criterio de cobertura de AC precisa ler. Confira tambem',
      '`git status --short` para nao perder arquivo nenhum.',
      'NAO reporte estilo, tipagem, tabs nem violacao de camada: o guardrails.py ja',
      'cobre isso deterministicamente e reportar de novo queima a rodada em ruido.',
      'Anexe os findings desta rodada a ' + cardDir + '/review.md.',
    ].join('\n'),
    { label: 'review:r' + round, phase: 'Review', model: 'sonnet', schema: REVIEW_SCHEMA },
  )

  const blockers = lastReview ? lastReview.findings.filter(f => f.blocking) : []
  log('Rodada ' + round + ': gate=' + (gateOk ? 'ok' : 'falhou') + ', bloqueantes=' + blockers.length)

  if (gateOk && blockers.length === 0) {
    break
  }
  if (round === MAX_ROUNDS) {
    log('Limite de ' + MAX_ROUNDS + ' rodadas atingido sem veredito limpo')
    break
  }

  const gateReport = gateOk
    ? 'Os portoes passaram.'
    : 'PORTAO FALHOU:\n' + ((lastGate && lastGate.output) || '(sem saida)')

  await agent(
    [
      'Leia PRIMEIRO a skill de implementacao em ' + SKILL_DEV + ' e siga-a.',
      '',
      CONTEXT,
      '',
      gateReport,
      '',
      'Findings bloqueantes a corrigir:',
      JSON.stringify(blockers, null, 2),
      '',
      'Tarefa: corrigir EXATAMENTE isto. Nao reabra o design, nao refatore o que nao',
      'foi apontado, nao mude a spec. Se um finding parecer errado, corrija o que da e',
      'explique o que discorda em vez de ignorar em silencio.',
      'Cada correcao com comportamento testavel headless ganha teste.',
    ].join('\n'),
    { label: 'fix:r' + round, phase: 'Fix', model: 'sonnet' },
  )
}

// ----------------------------------------------------------------- Smoke ----
phase('Smoke')
const smoke = await agent(
  [
    'Leia PRIMEIRO a skill de smoke test em ' + SKILL_SMOKE + ' e siga-a.',
    '',
    CONTEXT,
    'Spec: ' + cardDir + '/spec.md',
    'Pasta de evidencias: ' + cardDir + '/smoke/',
    '',
    'Tarefa: provar os ACs visuais do card com o programa rodando.',
    'ANTES de capturar, garanta que nenhum dado pessoal real pode aparecer na tela:',
    'dados/ vazio ou fixtures ficticias. PNG com nome real de aluno/docente e falha',
    'automatica do smoke, mesmo que o AC tenha passado.',
    'Capture com --write-movie SEMPRE limitado por --quit-after, renomeie os frames',
    'que provam cada AC pelo nome do AC, e apague o resto.',
    'Compare o log com um baseline; PNG bonito com push_error novo e falha.',
    'AC que exige interacao de mouse NAO pode ser automatizado neste projeto: marque',
    'como manual com roteiro, nunca declare sucesso no lugar do dev.',
    'Grave ' + cardDir + '/smoke/smoke.md.',
  ].join('\n'),
  { label: 'smoke:' + cardId, phase: 'Smoke', model: 'sonnet', schema: SMOKE_SCHEMA },
)

// O status do card, o indice e o commit ficam com o orquestrador, fora daqui:
// quem decide parar a fila precisa estar no circuito.
const blockers = lastReview ? lastReview.findings.filter(f => f.blocking) : []
const gateOk = lastGate
  && lastGate.guardrails_clean && lastGate.tests_passed && lastGate.parser_clean
const passed = Boolean(gateOk) && blockers.length === 0 && Boolean(smoke && smoke.smoke_passed)

log('Card ' + cardId + ': ' + (passed ? 'PASSOU' : 'FALHOU') + ' apos ' + round + ' rodada(s)')

return {
  cardId: cardId,
  passed: passed,
  rounds: round,
  spec: spec,
  gate: lastGate,
  remainingFindings: lastReview ? lastReview.findings : [],
  blockingFindings: blockers,
  smoke: smoke,
}
