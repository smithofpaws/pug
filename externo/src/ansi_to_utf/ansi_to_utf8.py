# Compilar no VSCode utilizando:
# python -m PyInstaller --onefile .\ansi_to_utf8.py
import sys

if len(sys.argv) < 3:  # 2 args plus script name
    print("Use: script.exe <input_file_path> <output_file_path>")
    sys.exit(1)

# Input file path
input_file_path = sys.argv[1]
# Output file path
output_file_path = sys.argv[2]

# Open ANSI file and read its content
with open(input_file_path, "r", encoding="ansi", errors="replace") as f:
    conteudo = f.read()

# Salvar o conteúdo em UTF-8
with open(output_file_path, "w", encoding="utf-8") as f:
    f.write(conteudo)

print(f"Conversão concluída: {output_file_path}")

