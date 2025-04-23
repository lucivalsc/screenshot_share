import os

def create_structure(base_path, structure):
    for key, value in structure.items():
        path = os.path.join(base_path, key)
        if isinstance(value, dict):
            os.makedirs(path, exist_ok=True)
            create_structure(path, value)
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(value)

directory_structure = {
    "lib": {
        "src": {
            "config": {
                "screenshot_config.dart": "// Configurações para captura de tela\n"
            },
            "enums": {
                "share_mode.dart": "// Enum para modos de compartilhamento\n"
            },
            "models": {
                "screenshot_data.dart": "// Modelo para dados da captura\n"
            },
            "services": {
                "screenshot_service.dart": "// Serviço de captura de tela\n",
                "screenshot_manager_service.dart": "// Gerenciamento de capturas\n",
                "storage_service.dart": "// Serviço de armazenamento\n"
            },
            "widgets": {
                "screenshot_wrapper.dart": "// Widget que encapsula a lógica de screenshot\n",
                "dual_button_wrapper.dart": "// Widget com dois botões para ações\n"
            }
        },
        "flutter_screenshot_telegram.dart": "// Biblioteca principal do pacote\n"
    },
    "example": {
        "lib": {
            "main.dart": "// Exemplo de uso do pacote\n"
        }
    },
    "test": {
        "flutter_screenshot_telegram_test.dart": "// Testes unitários do pacote\n"
    }
}

# Defina o caminho base onde deseja criar a estrutura
base_path = r"C:\Projetos\Flutter\Lucival\screenshot_share"

create_structure(base_path, directory_structure)

print("Estrutura do projeto 'flutter_screenshot_telegram' criada com sucesso!")
