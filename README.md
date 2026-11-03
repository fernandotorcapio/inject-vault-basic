# Inject Vault Basic

Aplicativo nativo iPhone (iOS 16+) com catálogo pesquisável, cadastro local de equipamentos e exportação JSON. A versão Basic não inclui NFC, conexão com máquinas ou liberação de créditos. Não requer chaves de API ou credenciais Apple para compilar sem assinatura.

## Compilação gratuita no GitHub

1. Crie um repositório **público** na sua conta, por exemplo `inject-vault-basic`, e envie o conteúdo deste pacote. Não envie logs, credenciais, bancos de dados ou arquivos de outras pastas.
2. Acesse **Actions → Build basic iPhone app → Run workflow**. O fluxo é manual; não há agendamento, retries ou execução automática em cada push.
3. O runner padrão `macos-15` compila com Xcode sem assinatura. O fluxo executa os testes do núcleo, verifica o perfil Basic e falha se o binário carregar CoreNFC.
4. Se o fluxo terminar com sucesso, abra **Releases** e baixe `InjectVault-Basic-unsigned.ipa`, `SHA256SUMS.txt` e a captura do simulador.

Os runners padrão em repositórios públicos têm execução gratuita segundo o GitHub. Os arquivos são publicados como assets de release; não são usados cache, armazenamento de artefatos do Actions ou runners maiores. Um workflow configurado não comprova build bem-sucedido; confira o resultado do run. Nenhuma conta Apple ou certificado é enviado ao GitHub.

## Instalar no Windows

O IPA produzido é intencionalmente **não assinado**. Não abre diretamente pela Câmera ou Safari e não é um link TestFlight.

Use o [Sideloadly oficial](https://sideloadly.io/), seguindo seus pré-requisitos atuais de componentes Apple no Windows. Não desinstale programas Apple ou mude sua configuração de segurança sem revisar o impacto. Conecte o iPhone desbloqueado por USB, confirme confiança no PC, selecione o aparelho, arraste seu IPA para o Sideloadly e entre com sua conta Apple no próprio programa. Nunca coloque senha Apple, código de verificação ou certificado nos arquivos deste projeto, no GitHub ou no chat.

Com uma conta Apple gratuita, a assinatura dura sete dias e segue os limites oficiais de quantidade de apps. A renovação usa o Sideloadly; esta aplicação não contorna esses limites. Se o iPhone solicitar, ative Modo de Desenvolvedor e confirme o perfil de desenvolvimento associado à sua conta em Ajustes. A instalação e autenticação dependem da interação do proprietário do aparelho.

## Teste no iPhone

- Abra **Vault Basic** e busque `Pixmaq` no catálogo. Deve aparecer a documentação, sem conexão com a máquina.
- Em **Meus cadastros**, salve um equipamento próprio. Feche e abra o app: o cadastro deve persistir.
- Em **Sobre**, prepare a exportação JSON e salve o arquivo no app Arquivos.
- A versão Basic deve mostrar claramente que não possui NFC nem controle de créditos.

## Abrir o projeto

O projeto desta versão é `InjectVaultBasic.xcodeproj`, esquema `InjectVaultBasic`. O entitlement de assinatura é vazio; o flag `VAULT_BASIC` exclui o leitor NFC da compilação. `InjectVault.xcodeproj` é o projeto original, separado, e não deve ser selecionado para o fluxo gratuito.

Fontes de suporte: [GitHub Actions](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [Sideloadly FAQ](https://sideloadly.io/faq). Sem jailbreak, contas alternativas para cotas, certificados emprestados ou serviços de assinatura pagos.
