# 🚀 Flux — Guia de Configuração e Execução

---

## 📋 Pré-requisitos

Antes de começar, certifique-se de ter instalado:

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Git](https://git-scm.com/)
- [Docker](https://www.docker.com/) (Docker Desktop no Windows/Mac ou Docker Engine no Linux)
- Uma conta no [Ngrok](https://ngrok.com/) para obter seu token de autenticação.

---

## 📱 1. Rodando o App Flutter no Celular

1. Conecte seu celular ao computador via USB com a **Depuração USB** ativada nas opções de desenvolvedor.
2. Na raiz do projeto, instale as dependências:

```bash
   flutter pub get

```

3. Execute o aplicativo:
```bash
flutter run lib/main.dart

```



O app será compilado e iniciado diretamente no seu dispositivo.

---

## 🐳 2. Rodando o Servidor de Forma Automatizada (Qualquer Máquina)

Basta rodar o comando abaixo em qualquer terminal Linux ou WSL, substituindo `SEU_TOKEN_REAL_DO_NGROK` com a credencial do seu painel do Ngrok:

```bash
docker run -it --rm -p 9000:9000 -e NGROK_AUTHTOKEN=SEU_TOKEN_REAL_DO_NGROK gaffix/flux-server:latest

```

---

## 🔗 3. Conectando o App ao Servidor

Assim que o comando do Docker terminar de iniciar, uma mensagem aparecerá no seu terminal assim:

```text
============================================================
🚀 LINK PARA COLOCAR NO APLICATIVO FLUX:
👉 [https://abcd-123-45-67.ngrok-free.app](https://abcd-123-45-67.ngrok-free.app) 👈
============================================================

```

1. **Copie** a URL gerada (com o `https://`).
2. Abra o aplicativo **Flux** no seu celular.
3. Toque no ícone de **Configurações** (engrenagem).
4. **Cole** a nova URL no campo do servidor e salve.

Pronto! Seu aplicativo está conectado ao backend e pronto para buscar e reproduzir as músicas direto do YouTube.

---

## 🛑 Como Desligar o Servidor

Para encerrar o servidor e fechar o túnel do Ngrok com segurança, basta voltar ao terminal onde o Docker está rodando e pressionar:

```bash
Ctrl + C

```
