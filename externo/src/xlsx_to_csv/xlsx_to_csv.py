import os
import pandas as pd

# Ajuste estes caminhos para as pastas da sua maquina antes de rodar.
input_directory = './Respostas/'
output_directory = './out/'

for filename in os.listdir(input_directory):
    if filename.endswith(".xlsx"):
        xlsx_file = os.path.join(input_directory, filename)
        csv_file = os.path.join(output_directory, os.path.splitext(filename)[0] + ".csv")
        data = pd.read_excel(xlsx_file)
        data.to_csv(csv_file, index=False)
        print(f"Converted {xlsx_file} to {csv_file}")
