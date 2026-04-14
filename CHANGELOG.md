## 0.1.3
* Atualização de dependências para compatibilidade com Flutter 3.35.4 e Dart 3.9.2.
* Atualizado constraint de SDK para >=3.0.0 <4.0.0.
* Atualizado constraint de Flutter para >=3.35.0.
* Atualizado archive para ^4.0.9.
* Atualizado image para ^4.8.0.

## 0.1.2
* Atualização de pacotes para a versão mais recente.
* Atualização das resoluções para focar apenas em modo portrait (celular e tablet).
* Adicionado enum DeviceType para filtrar os dispositivos desejados.
* Otimização do processamento de imagens utilizando Isolates para não travar a UI.
* Refatoração da estrutura de serviços (TelegramService separado).

## 0.1.1+1
* Correção de versão.

## 0.1.0
* Lançamento inicial com as seguintes funcionalidades:
* Modo de botão único para captura e compartilhamento imediato.
* Modo de botão duplo para capturar várias capturas de tela e compartilhar posteriormente.
* Várias opções de compartilhamento:
    * Enviar para o Telegram via Bot API.
    * Salvar no armazenamento local.
    * Compartilhar com outros aplicativos.
* Tamanhos e qualidade de captura de tela configuráveis.
* Opção de mostrar botões apenas no modo debug.