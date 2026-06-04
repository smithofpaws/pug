// template_ementa_v01

#set table.hline(stroke: 0pt)
#set table.vline(stroke: 0pt)

// imagem fora da tabela
#align(center)[#figure(image("unipampa.svg", width:90%))]

#table(
  columns: (65%, 35%),
  table.cell(colspan: 2, align: center, fill: silver, )[*Identificação do Componente*], 
  [Código do Componente Curricular: ], [CH Total: [[ch_tot]]h], table.hline(start: 0),
  [[[cod_componente]]], [CH Presencial Teórica: [[ch_pres_t]]h], 
table.hline(start: 0),

  table.cell(align: top, )[Nome do Componente Curricular: [[nome_componente]]], [CH Presencial Prática: [[ch_pres_p]]h], table.hline(start: 0),

  table.cell(align: top, )[], [CH EaD Teórica: [[ch_ead_t]]h], table.hline(start: 0),

  table.cell(align: top, )[], [CH EaD Prática: [[ch_ead_p]]h], table.hline(start: 0),

  table.cell(align: top, )[], [CH de Extensão: [[ch_ext]]h], 
table.hline(start: 2),
  
  table.cell(colspan: 2, align: center, fill:silver)[*Ementa*],

  table.cell(colspan: 2)[[[texto_ementa]]],
table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Objetivo Geral*],

  table.cell(colspan: 2)[[[texto_obj_geral]]], 
table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Objetivos Específicos*], 
  table.cell(colspan: 2)[
    [[objetivos_especificos]]
  ], table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Referências Bibliográficas Básicas*], 
  table.cell(colspan: 2)[
    #set list(marker: none, body-indent: 0pt)
    #list(
      "[[ref_basica]]"
    )
  ], table.hline(start: 2),

  table.cell(colspan: 2, align: center, fill:silver)[*Referências Bibliográficas Complementares*], 
  table.cell(colspan: 2)[
    #set list(marker: none, body-indent: 0pt)
    #list(
      "[[ref_complementar]]"
    )
  ]
)