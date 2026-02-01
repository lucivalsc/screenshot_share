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