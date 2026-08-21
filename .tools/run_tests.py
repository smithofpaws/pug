#!/usr/bin/env python3
"""Roda a suite de testes GUT headless. Ponto de entrada unico.

    python .tools/run_tests.py                     # suite inteira
    python .tools/run_tests.py -gselect=horarios   # flags extras vao direto ao GUT

Existe para haver UMA linha de invocacao de teste no projeto, citada igual pelo
Lefthook, pelo workflow e pelas skills. Tambem resolve o caminho do binario do
Godot, que no Windows tem espaco e nao sobrevive a interpolacao de shell dos
gerenciadores de hook.

Exit code: 0 se todos os testes passam, diferente de 0 caso contrario. As opcoes
da suite (diretorio, prefixo, exit) vivem em .gutconfig.json, nao aqui.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GUT_ENTRY = "res://addons/gut/gut_cmdln.gd"

# Preferencia pelo Godot_console.exe no Windows: o Godot.exe comum e uma app GUI
# e nao devolve stdout ao terminal, o que deixaria o portao cego.
CANDIDATES = [
	r"C:\Program Files\Godot\Godot_console.exe",
	r"C:\Program Files\Godot\Godot.exe",
	"/usr/local/bin/godot",
	"/usr/bin/godot",
]


def find_godot():
	env_path = os.environ.get("GODOT_PATH")
	if env_path and Path(env_path).exists():
		return env_path
	for candidate in CANDIDATES:
		if Path(candidate).exists():
			return candidate
	for name in ("godot_console", "godot"):
		found = shutil.which(name)
		if found:
			return found
	return ""


def main(argv):
	godot = find_godot()
	if not godot:
		sys.stderr.write(
			"run_tests: binario do Godot nao encontrado. Defina GODOT_PATH ou instale "
			"em um dos caminhos conhecidos:\n  " + "\n  ".join(CANDIDATES) + "\n")
		return 2
	if not (REPO_ROOT / "addons" / "gut" / "gut_cmdln.gd").exists():
		sys.stderr.write("run_tests: addons/gut nao encontrado. Instale o GUT 9.x.\n")
		return 2

	command = [godot, "--headless", "--path", str(REPO_ROOT), "-s", GUT_ENTRY] + list(argv)
	result = subprocess.run(command)
	return result.returncode


if __name__ == "__main__":
	sys.exit(main(sys.argv[1:]))
