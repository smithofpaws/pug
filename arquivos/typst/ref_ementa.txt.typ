// template_ementa_v01

#set table.hline(stroke: 0pt)
#set table.vline(stroke: 0pt)

// imagem fora da tabela
#align(center)[#figure(image("unipampa.svg", width:90%))]

#table(
  columns: (65%, 35%),
  table.cell(colspan: 2, align: center, fill: silver, )[*Identificação do Componente*], 
  [Código do Componente Curricular: ], [CH Total: 30h], table.hline(start: 0),
  [AL0000], [CH Presencial Teórica: 30h], 
table.hline(start: 0),

  table.cell(align: top, )[Nome do Componente Curricular: Introdução à Engenharia Civil], [CH Presencial Prática: 0h], table.hline(start: 0),

  table.cell(align: top, )[], [CH EaD Teórica: 0h], table.hline(start: 0),

  table.cell(align: top, )[], [CH EaD Prática: 0h], table.hline(start: 0),

  table.cell(align: top, )[], [CH de Extensão: 0h], 
table.hline(start: 2),
  
  table.cell(colspan: 2, align: center, fill:silver)[*Ementa*],

  table.cell(colspan: 2)[A evolução tecnológica ao longo dos tempos. Disseminação da cultura científica e tecnológica. Organização do curso de Engenharia Civil. Atividades de ensino e pesquisa propostos. Caracterização da profissão, de suas diversas áreas e do profissional. Formação acadêmica do engenheiro civil e suas atribuições profissionais. Oportunidades ocupacionais. O setor da construção civil na cidade, no estado e no país.],
table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Objetivo Geral*],

  table.cell(colspan: 2)[Conhecer os objetivos do curso e sua estrutura curricular, a metodologia científica e tecnológica, a comunicação e a expressão na área científica e tecnológica, do projeto do curso e do profissional da Engenharia Civil.], 
table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Objetivos Específicos*], 
  table.cell(colspan: 2)[
    Aqui vai o objetivo especifico por extenso, se existir.
    #list(
      "Apresentar um panorama sobre os cursos da área da tecnologia, as áreas de atuação, carreira profissional e oportunidades de desenvolvimento",
      "Promover o encontro dos alunos com profissionais da área tecnológica e científica através de seminários interativos;",
      "Familiarizar os alunos com noções que serão aplicadas e terão importância ao longo de todo o curso de graduação;",
      "Auxiliar o aluno a orientar-se e ter uma atitude crítica diante do complexo sistema do conhecimento científico moderno, procurando aprimorar a comunicação e a expressão na área científica e tecnológica;",
      "Fornecer algumas noções sobre os principais períodos históricos da evolução da ciência e identificar alguns dos principais personagens dessa evolução.",
    )
  ], table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Referências Bibliográficas Básicas*], 
  table.cell(colspan: 2)[
    #set list(marker: none, body-indent: 0pt)
    #list(
        "BAZZO, W. A. Introdução à engenharia / Conceitos, ferramentas e comportamentos. 1. ed. Florianópolis: UFSC, 2007;",
        "CERVO, A. L. Metodologia científica 5. ed. São Paulo: Pearson Prentice Hall, 2006;",
        "CHALMERS, A. F. O que é ciência afinal. (Trad. por Raul Fiker da 2. ed. em inglês). São Paulo: Brasiliense, 2008;",
    )
  ], table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Referências Bibliográficas Complementares*], 
  table.cell(colspan: 2)[
    #set list(marker: none, body-indent: 0pt)
    #list(
        "BAZZO, W. A.; PEREIRA, L. T. V.; LINSINGEN, I. Educação Tecnológica. Florianópolis: UFSC, 2000;",
        "BROCKMAN, J. B. Introdução à engenharia: modelagem e solução de problemas. Rio de Janeiro: LTC, 2010;",
        "FEITOSA, V. C. Comunicação na Tecnologia – Manual de Redação Científica. São Paulo: Brasiliense, 1987;",
        "HOLTZAPPLE, M. T.; REECE, W. D. Introdução à engenharia. 1. ed. Rio de Janeiro, RJ: LTC, 2006;",
        "KLEIMAN, A. Oficina de Leitura: teoria e prática. 4. ed. Campinas: E. UNICAMP, 1996.",
        "",
    )
  ]
)
